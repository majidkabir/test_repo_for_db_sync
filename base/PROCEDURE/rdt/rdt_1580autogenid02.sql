SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1580AutoGenID02                                 */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2018-08-02   Ung       1.0   WMS-5722 Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580AutoGenID02]
   @nMobile     INT,
   @nFunc       INT,
   @nStep       INT,
   @cLangCode   NVARCHAR( 3),
   @cReceiptKey NVARCHAR( 10),
   @cPOKey      NVARCHAR( 10),
   @cLOC        NVARCHAR( 10),
   @cID         NVARCHAR( 18),
   @cOption     NVARCHAR( 1),
   @cAutoID     NVARCHAR( 18) OUTPUT,
   @nErrNo      INT           OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_success INT
   DECLARE @n_ErrNo   INT
   DECLARE @c_errmsg  CHAR( 250)
   DECLARE @c_ID      NvarCHAR( 10)

   IF @nStep = 2 OR                    -- FromLOC 
      (@nStep = 6 AND @cOption = '1')  -- Print pallet label screen, 1=Yes, 2=No
   BEGIN
   	EXECUTE dbo.nspg_GetKey
   		'ID', 
   		10,
   		@c_ID      OUTPUT,
   		@b_success OUTPUT,
   		@n_ErrNo   OUTPUT,
   		@c_errmsg  OUTPUT
   
      IF @b_success <> 1 -- FAIL
   	   SET @cAutoID = ''
   	ELSE
   	BEGIN
   	   -- Format: LFYYMMDD9999
   	   --    LF = Prefix
   	   --    YYMMDD = ISO date format
   	   --    9999 = last 4 digits of pallet ID. Don't need serialize
	      SET @cAutoID =                            
   	      'LF' +                                 
   	      CONVERT( NVARCHAR(6), GETDATE(), 12) + 
   	      RIGHT( @c_ID, 4)                       
   	END
   END
END

GO