# Phase 3 is staged so the learner can see that a route alone is insufficient.
variable "phase3_enable_spoke1_route" {
  description = "Route from Spoke 1 to Spoke 2 via hub NVA."
  type        = bool
  default     = false
}

variable "phase3_enable_spoke2_route" {
  description = "Return route from Spoke 2 to Spoke 1 via hub NVA."
  type        = bool
  default     = false
}

variable "phase3_enable_hub_forwarding" {
  description = "Enable Azure NIC IP forwarding on existing Phase 2 hub VM NIC."
  type        = bool
  default     = false
}
