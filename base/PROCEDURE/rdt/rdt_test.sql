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

CREATE   PROCEDURE [RDT].[rdt_test] (
   @nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

create table ta(id int)
create table tb(id int)


BEGIN TRY
BEGIN TRAN
    insert ta select '1fhjh'
commit tran
end TRY
BEGIN CATCH
    print 123123
    insert tb select '123d'
    ROLLBACK TRAN
END CATCH

drop table ta
drop table tb



END

GO