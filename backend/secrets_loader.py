"""
Secrets Loader Module
Loads configuration from AWS SSM Parameter Store and Secrets Manager with LRU caching.
Falls back to environment variables if SSM/Secrets unavailable (graceful degradation).

Usage:
    from secrets_loader import SecureConfig
    config = SecureConfig()
    secret_val = config.get_secret("formbridge/prod/HMAC_SECRET")
    param_val = config.get_param("formbridge/prod/ses/recipients")
"""

import os
import json
import logging
import time
from typing import Optional, Dict, Any
from functools import lru_cache
from botocore.exceptions import ClientError
import boto3

logger = logging.getLogger(__name__)

# Configuration
CACHE_TTL_SECONDS = 600  # 10 minutes
TIMEOUT_SECONDS = 2  # Timeout for SSM/Secrets calls
LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")

logger.setLevel(LOG_LEVEL)


class SecureConfig:
    """
    Manages secure configuration loading with caching and fallbacks.
    
    Priority order:
    1. In-memory cache (if not expired)
    2. AWS SSM Parameter Store (for parameters)
    3. AWS Secrets Manager (for secrets)
    4. Environment variables (fallback)
    """
    
    def __init__(self):
        """Initialize SSM and Secrets Manager clients."""
        self.ssm_client = boto3.client("ssm", region_name=os.environ.get("AWS_REGION"))
        self.secrets_client = boto3.client("secretsmanager", region_name=os.environ.get("AWS_REGION"))
        self._cache: Dict[str, tuple[Any, float]] = {}  # {key: (value, timestamp)}
        self.cache_version = 0
    
    def _is_cache_valid(self, cache_key: str) -> bool:
        """Check if cache entry exists and is not expired."""
        if cache_key not in self._cache:
            return False
        
        cached_value, timestamp = self._cache[cache_key]
        if time.time() - timestamp > CACHE_TTL_SECONDS:
            del self._cache[cache_key]
            return False
        
        return True
    
    def _get_from_cache(self, cache_key: str) -> Optional[Any]:
        """Retrieve value from cache if valid."""
        if self._is_cache_valid(cache_key):
            logger.debug(f"Cache hit for {cache_key}")
            return self._cache[cache_key][0]
        return None
    
    def _set_cache(self, cache_key: str, value: Any) -> None:
        """Store value in cache with current timestamp."""
        self._cache[cache_key] = (value, time.time())
        logger.debug(f"Cached {cache_key}")
    
    def get_param(
        self,
        name: str,
        decrypt: bool = False,
        fallback_env: Optional[str] = None
    ) -> Optional[str]:
        """
        Retrieve parameter from SSM Parameter Store with cache and fallback.
        
        Args:
            name: SSM parameter name (e.g., /formbridge/prod/ses/recipients)
            decrypt: Whether to decrypt SecureString parameters
            fallback_env: Environment variable name to fallback to if SSM fails
        
        Returns:
            Parameter value or None if not found
        """
        cache_key = f"param:{name}:v{self.cache_version}"
        
        # Check cache first
        cached = self._get_from_cache(cache_key)
        if cached is not None:
            return cached
        
        # Try SSM Parameter Store
        try:
            logger.debug(f"Fetching parameter {name} from SSM")
            response = self.ssm_client.get_parameter(
                Name=name,
                WithDecryption=decrypt
            )
            value = response["Parameter"]["Value"]
            self._set_cache(cache_key, value)
            logger.info(f"Successfully loaded {name} from SSM")
            return value
        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code", "Unknown")
            logger.warning(f"SSM get_parameter failed for {name}: {error_code}. Using fallback.")
        except Exception as e:
            logger.warning(f"SSM get_parameter error for {name}: {str(e)}. Using fallback.")
        
        # Fallback to environment variable
        if fallback_env:
            env_value = os.environ.get(fallback_env)
            if env_value:
                self._set_cache(cache_key, env_value)
                logger.info(f"Using fallback env var {fallback_env} for {name}")
                return env_value
        
        logger.warning(f"No value found for {name} (SSM failed, no fallback)")
        return None
    
    def get_secret(
        self,
        name: str,
        fallback_env: Optional[str] = None
    ) -> Optional[str]:
        """
        Retrieve secret from AWS Secrets Manager with cache and fallback.
        
        Args:
            name: Secret name (e.g., formbridge/prod/HMAC_SECRET)
            fallback_env: Environment variable name to fallback to if Secrets Manager fails
        
        Returns:
            Secret value or None if not found
        """
        cache_key = f"secret:{name}:v{self.cache_version}"
        
        # Check cache first
        cached = self._get_from_cache(cache_key)
        if cached is not None:
            return cached
        
        # Try Secrets Manager
        try:
            logger.debug(f"Fetching secret {name} from Secrets Manager")
            response = self.secrets_client.get_secret_value(SecretId=name)
            
            # Handle both string and JSON secrets
            if "SecretString" in response:
                value = response["SecretString"]
                # Try to parse as JSON, but if not valid JSON, return as string
                try:
                    parsed = json.loads(value)
                    self._set_cache(cache_key, parsed)
                    logger.info(f"Successfully loaded {name} from Secrets Manager (JSON)")
                    return parsed
                except json.JSONDecodeError:
                    self._set_cache(cache_key, value)
                    logger.info(f"Successfully loaded {name} from Secrets Manager (string)")
                    return value
            else:
                logger.warning(f"No SecretString in response for {name}")
        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code", "Unknown")
            logger.warning(f"Secrets Manager get_secret_value failed for {name}: {error_code}. Using fallback.")
        except Exception as e:
            logger.warning(f"Secrets Manager error for {name}: {str(e)}. Using fallback.")
        
        # Fallback to environment variable
        if fallback_env:
            env_value = os.environ.get(fallback_env)
            if env_value:
                self._set_cache(cache_key, env_value)
                logger.info(f"Using fallback env var {fallback_env} for {name}")
                return env_value
        
        logger.warning(f"No value found for {name} (Secrets Manager failed, no fallback)")
        return None
    
    def invalidate_cache(self) -> None:
        """Invalidate all cached values by incrementing version."""
        self.cache_version += 1
        logger.info(f"Cache invalidated. New version: {self.cache_version}")


# Global instance for Lambda to use
_config_instance: Optional[SecureConfig] = None


def get_config() -> SecureConfig:
    """Get or create the global SecureConfig instance."""
    global _config_instance
    if _config_instance is None:
        _config_instance = SecureConfig()
        logger.info("SecureConfig instance created")
    return _config_instance


def get_param(
    name: str,
    decrypt: bool = False,
    fallback_env: Optional[str] = None
) -> Optional[str]:
    """Convenience function to get parameter from global config instance."""
    return get_config().get_param(name, decrypt, fallback_env)


def get_secret(
    name: str,
    fallback_env: Optional[str] = None
) -> Optional[str]:
    """Convenience function to get secret from global config instance."""
    return get_config().get_secret(name, fallback_env)


def invalidate_cache() -> None:
    """Convenience function to invalidate cache."""
    return get_config().invalidate_cache()
