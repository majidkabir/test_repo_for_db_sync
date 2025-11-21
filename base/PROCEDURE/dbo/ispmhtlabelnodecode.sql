SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispMHTLabelNoDecode                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Decode GS1-128 barcode                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 25-03-2014  1.0  Ung         SOS305459. Created                      */
/* 18-09-2015  1.1  Ung         SOS352987. Add new format               */
/* 27-03-2017  1.2  Ung         WMS-1373 Add pallet ID                  */
/* 2023-02-16  1.3  WyeChun     JSM-129049 Extend oFieled09 (20)        */    
/*                              and CaseID (18) length to 40 , and      */    
/*                              LabelNo (30) length to 60 to store      */    
/*                              the proper barcode (WC01)               */  
/************************************************************************/

CREATE PROCEDURE [dbo].[ispMHTLabelNoDecode]
   @c_LabelNo          NVARCHAR(60),   --WC01 
   @c_Storerkey        NVARCHAR(15),
   @c_ReceiptKey       NVARCHAR(10),
   @c_POKey            NVARCHAR(10),
	@c_LangCode	        NVARCHAR(3),
	@c_oFieled01        NVARCHAR(60) OUTPUT, -- SKU
	@c_oFieled02        NVARCHAR(20) OUTPUT,
   @c_oFieled03        NVARCHAR(20) OUTPUT,
   @c_oFieled04        NVARCHAR(20) OUTPUT,
   @c_oFieled05        NVARCHAR(20) OUTPUT,
   @c_oFieled06        NVARCHAR(20) OUTPUT,
   @c_oFieled07        NVARCHAR(20) OUTPUT,
   @c_oFieled08        NVARCHAR(20) OUTPUT, -- Lottable02, BatchNo
   @c_oFieled09        NVARCHAR(40) OUTPUT, -- Lottable03, CaseID   --WC01 
   @c_oFieled10        NVARCHAR(20) OUTPUT, -- Pallet ID
   @b_Success          INT = 1  OUTPUT,
   @n_ErrNo            INT      OUTPUT, 
   @c_ErrMsg           NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cSKU      NVARCHAR( 20)
   DECLARE @cBatchNo  NVARCHAR( 18)
   DECLARE @cCaseID   NVARCHAR( 40)  --WC01 
   DECLARE @cPalletID NVARCHAR( 18)
   DECLARE @nPOS      INT

   SET @cSKU = ''
   SET @cBatchNo = ''
   SET @cCaseID = ''
   SET @cPalletID = ''

   -- Pallet ID
   IF LEFT( @c_LabelNo, 2) = 'ID'
   BEGIN
      SET @cPalletID = LEFT( @c_oFieled01, 18)
      SET @c_oFieled10 = @cPalletID
      GOTO Quit
   END
   
   -- Case ID
   /*
   Barcode format:
   1. (01)EAN21CaseID(10)BatchNo
   2. (01)EAN21CaseID
   3. (01)EAN10BatchNo(21)CaseID
   
   EAN     = fixed 14 digits (DB 13 digits)
   CaseID  = fixed 5 digits
   BatchNo = alpha numeric, optional. 
         
   Example:
   (01)032459900099242100003(10)TEST5
   (01)032459900099242100003
   */
   
   -- 1st delimeter
   IF LEFT( @c_LabelNo, 4) = '(01)'
   BEGIN
      -- Decode SKU
      SET @cSKU = SUBSTRING( @c_LabelNo, 6, 13)
      SET @c_LabelNo = SUBSTRING( @c_LabelNo, 19, LEN( @c_LabelNo))

      -- 2nd delimeter
      IF LEFT( @c_LabelNo, 2) = '21'
      BEGIN
         -- Decode Case ID
         SET @nPOS = PATINDEX( '%(10)%', @c_LabelNo)
         IF @nPOS = 0
         BEGIN
            SET @cCaseID = SUBSTRING( @c_LabelNo, 3, LEN( @c_LabelNo))
            SET @c_LabelNo = ''
         END
         ELSE
         BEGIN
            SET @cCaseID = SUBSTRING( @c_LabelNo, 3, @nPOS-3)
            SET @c_LabelNo = SUBSTRING( @c_LabelNo, @nPOS, LEN( @c_LabelNo))
         END

         -- 3rd delimeter
         IF LEFT( @c_LabelNo, 4) = '(10)'
            -- Decode Batch no
            SET @cBatchNo = SUBSTRING( @c_LabelNo, 5, LEN( @c_LabelNo))
      END
      
      -- 2nd delimeter
      ELSE IF LEFT( @c_LabelNo, 2) = '10'
      BEGIN
         -- Decode Batch no
         SET @nPOS = PATINDEX( '%(21)%', @c_LabelNo)
         IF @nPOS = 0
         BEGIN
            SET @cBatchNo = SUBSTRING( @c_LabelNo, 3, LEN( @c_LabelNo))
            SET @c_LabelNo = ''
         END
         ELSE
         BEGIN
            SET @cBatchNo = SUBSTRING( @c_LabelNo, 3, @nPOS-3)
            SET @c_LabelNo = SUBSTRING( @c_LabelNo, @nPOS, LEN( @c_LabelNo))
         END

         -- 3rd delimeter
         IF LEFT( @c_LabelNo, 4) = '(21)'
            -- Decode CaseID
            SET @cCaseID = SUBSTRING( @c_LabelNo, 5, LEN( @c_LabelNo))
      END
   END

   /*
   Barcode format:
   1. (10)BatchNo(21)CaseID
   
   BatchNo = alpha numeric, variable length
   CaseID  = max 20 digits
   
   Example:
   (10)327516(21)032751600030
   */

   ELSE IF LEFT( @c_LabelNo, 4) = '(10)'
   BEGIN
      -- Decode Batch no
      SET @nPOS = PATINDEX( '%(21)%', @c_LabelNo)
      IF @nPOS > 0
      BEGIN
         SET @cBatchNo = SUBSTRING( @c_LabelNo, 5, @nPOS-5)
         SET @c_LabelNo = SUBSTRING( @c_LabelNo, @nPOS, LEN( @c_LabelNo))
      END

      -- Decode case ID
      IF LEFT( @c_LabelNo, 4) = '(21)'
         SET @cCaseID = SUBSTRING( @c_LabelNo, 5, LEN( @c_LabelNo))
   END
   ELSE
      SET @cSKU = @c_oFieled01
         
   -- Return value
   SET @c_oFieled01 = @cSKU

   IF @cBatchNo <> ''
      SET @c_oFieled08 = @cBatchNo
   IF @cCaseID <> ''
      SET @c_oFieled09 = @cCaseID
     
QUIT:
END -- End Procedure


GO