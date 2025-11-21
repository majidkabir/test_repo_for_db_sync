SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1580ExtInfo01                                   */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Display Count                                               */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2018-04-19 1.0  ChewKP   WMS-4126 Created                            */
/* 2022-05-19 1.1  Ung      WMS-19667 Migrate to new ExtendedInfoSP     */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_test2] (
   @nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @ntrancount int
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN Step_3_Upd1 -- For rollback or commit only our own transaction
   Begin Try
         insert into traceinfo ( tracename , timein,step1,step2)
         values('DennisTest',GETDATE(),1, 3)
         select 1/0
   end Try
   Begin catch
      if XACT_STATE() <> -1
         RollBack transaction
        print 11
        goto quit
   end catch

   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
   COMMIT TRAN
quit:

END

GO