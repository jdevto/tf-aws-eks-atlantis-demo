package main

import future.keywords.if
import future.keywords.in
import future.keywords.contains

resource_types contains "null_resource"

# all resources
resources[resource_type] contains name if {
  some resource_type in resource_types
  some name in input.resource_changes
  name.type == resource_type
}

# number of creations of resources of a given type
  num_creates[resource_type] := num if {
  some resource_type in resource_types
  all := resources[resource_type]
  creates := [res |
    some res in all
    "create" in res.change.actions
  ]
  num := count(creates)
}

deny contains msg if {
  num_resources := num_creates["null_resource"]
  num_resources > 0
  msg := "null resources cannot be created"
}
