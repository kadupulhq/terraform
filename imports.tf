# These repositories already exist. Import blocks make the first plan adopt them
# instead of trying to create them. Remove a block once its resource is in
# state, or leave it: import is a no-op after the first apply.
import {
  to = github_repository.this["kadupul"]
  id = "kadupul"
}

import {
  to = github_repository.this["website"]
  id = "website"
}
