CREATE TRIGGER trigger_generate_direct_journal
AFTER INSERT ON credits
FOR EACH ROW
EXECUTE FUNCTION generate_direct_journal();
