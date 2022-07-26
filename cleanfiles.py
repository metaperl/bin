from pathlib import Path
from loguru import logger
import arrow

files_path = r"c:/Users/thequ/Downloads/"

critical_time = arrow.now().shift(hours=+5).shift(days=-7)

for item in Path(files_path).glob('*'):
    try:
        if item.is_file():
            logger.info(f"{item}")
            if "SCPGA" in str(item):
                logger.info("\tskipping.")
                continue
            item_time = arrow.get(item.stat().st_mtime)
            logger.info(f"\t{item_time} vs {critical_time}")
            if item_time < critical_time:
                logger.info("\tunlinking")
                
                item.unlink()
            else:
                logger.info("\tNot old enough")
        else:
            logger.info(f"\t{item} is not a file.")
    except UnicodeEncodeError:
        logger.warning(f"Failure on {item}")
