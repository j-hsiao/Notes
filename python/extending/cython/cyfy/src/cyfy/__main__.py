import sys
from cyfy import repo

sys.exit(repo.run(repo.parser().parse_args()))
