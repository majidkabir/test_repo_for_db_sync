SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtNIKEAutoGenID                                    */
/* Copyright: IDS                                                       */
/* Purpose: Generate lottable01 as ID                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2013-06-25   Ung       1.0   SOS273208 NIKE CN pallet ID format      */
/* 2017-02-27   TLTING    1.1   Variable Nvarchar                       */
/* 2020-05-05   Ung       1.2   WMS-13066 Remove prefix C               */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtNIKEAutoGenID]
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

   IF @nStep = 2 OR                        -- FromLOC 
      (@nStep = 6  AND @cOption = '1') OR  -- Print pallet label screen, 1=Yes, 2=No
      (@nStep = 10 AND @cOption = '1')     -- Close pallet label screen, 1=Yes, 2=No
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
         IF @nStep IN (6, 10) AND LEFT( @cID, 1) IN ('A', 'B')
            SET @cAutoID =       -- Format: 
               LEFT( @cID, 1) +  -- Prefix '0'. User will overwrite as A/B
               @c_ID             -- 10 digit pallet ID. Don't need serialize
         ELSE
            SET @cAutoID = -- Format: 
               '0' +       -- Prefix '0'. User will overwrite as A/B
               @c_ID       -- 10 digit pallet ID. Don't need serialize
      END
   END
END

GO