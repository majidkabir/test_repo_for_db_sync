SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/* 28-Oct-2013  TLTING     Review Editdate column update                */

CREATE TRIGGER [RDT].[ntrNSQLConfigUpdate] ON [RDT].[NSQLConfig] 
FOR UPDATE AS
BEGIN 
IF @@ROWCOUNT = 0
BEGIN
RETURN
END
   SET NOCOUNT ON
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF
	SET CONCAT_NULL_YIELDS_NULL OFF

 IF  NOT UPDATE(EditDate)
 BEGIN 	 	
   UPDATE rdt.NSQLConfig SET 
      EditDate = GETDATE(),
      EditWho = SUSER_SNAME()
   FROM rdt.NSQLConfig, INSERTED
   WHERE rdt.NSQLConfig.Function_ID = INSERTED.Function_ID
      AND rdt.NSQLConfig.ConfigKey = INSERTED.ConfigKey
 END        
END


GO