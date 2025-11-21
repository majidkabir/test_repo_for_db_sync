SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispGenAutoID                                        */
/* Copyright: IDS                                                       */
/* Purpose: Generate lottable01 as ID                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2012-04-04   Ung       1.0   SOS240680 new pallet ID format          */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispGenAutoID]
   @cReceiptKey NVARCHAR(10),
   @cLOC        NVARCHAR(10),
   @cAutoID     NVARCHAR(18) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_success INT
   DECLARE @n_ErrNo   INT
   DECLARE @c_errmsg  NVARCHAR( 250)
   DECLARE @c_ID      NVARCHAR( 7)

	EXECUTE dbo.nspg_GetKey
		'DSGPLID', 
		7,
		@c_ID      OUTPUT,
		@b_success OUTPUT,
		@n_ErrNo   OUTPUT,
		@c_errmsg  OUTPUT

   IF @b_success <> 1 -- FAIL
	   SET @cAutoID = ''
	ELSE
	   SET @cAutoID =                               -- Format: 
	      'D' +                                     -- Prefix 'D'
	      master.dbo.fnc_GetCharASCII( 65 + (YEAR( GETDATE()) - 2012)) +   -- A=2012, B=2013, C=2014...
	      @c_ID +                                   -- 7 digit pallet ID. Don't need serialize
	      '000'                                     -- Surfix '000'
END

GO