trigger PolicyChangeTrigger on Policy_Change__e(after insert) {
  PolicyChangeHandler.handle(Trigger.new);
}
