SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Function: rdt_RDTUserEncryption                               */
/* Copyright: Maersk                                                    */
/*                                                                      */
/* Purpose: UWP- 21905                                                 */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Version    Author   Purposes                            */
/* 2024-07-26   1.0        JACKC    UWP-21905 created                   */
/************************************************************************/
CREATE FUNCTION rdt.rdt_RDTUserEncryption
(
   @cUsrName    NVARCHAR(18),
   @cPassword   NVARCHAR(15)
)
RETURNS NVARCHAR(32)
BEGIN

   DECLARE
      @cEncryptPassword NVARCHAR(32) 
   
   SET @cEncryptPassword = MASTER.dbo.fnc_CryptoEncrypt(@cPassword, UPPER(@cUsrName))

   RETURN @cEncryptPassword
END

GO