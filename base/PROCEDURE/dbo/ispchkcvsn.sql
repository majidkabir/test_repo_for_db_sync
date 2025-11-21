SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispChkCVSN                                         */
/* Creation Date: 25-Sep-2006                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Ciba Vision Serial # Validation                             */
/*                                                                   	*/
/*                                                                      */
/* Called By: From ispChkCVSN base on Codelkup.sValue*/
/*            Tablename = PnPSerialNoCheckCode                          */ 
/*                                                                      */
/* PVCS Version: 1.0	 SOS#50956                                         */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/*                                                                      */
/************************************************************************/

CREATE PROC [dbo].[ispChkCVSN] (
   @cLoadKey    NVARCHAR(10),
   @cOrderKey   NVARCHAR(10),
   @cStorerKey  NVARCHAR(15), 
   @cSKU        NVARCHAR(20),
   @nQty        int,
   @cSerialNo   NVARCHAR(18), 
   @bSuccess    int = 1 OUTPUT,
   @nErr        int = 0 OUTPUT,
   @cErrmsg     NVARCHAR(250) = '' OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
      @nStrLength      int
     ,@cMonth          NVARCHAR(2)
     ,@cYear           NVARCHAR(4) 
     ,@cSKUGroup       NVARCHAR(10)
     ,@cExpiryDate     NVARCHAR(8)  


   SET @bSuccess = 1
   SET @cMonth = ''
   SET @cYear  = '' 
   
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@cSerialNo)) IS NULL OR dbo.fnc_LTrim(dbo.fnc_RTrim(@cSerialNo)) = '' 
   BEGIN
      SET @cErrmsg = 'Blank Serial No' 
      SET @bSuccess = 0 
      GOTO QUIT 
   END 

   SET @cSerialNo = ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@cSerialNo)), '')
   SET @nStrLength = LEN(@cSerialNo) 

   IF @nStrLength = 12 OR @nStrLength = 16 
   BEGIN   
      SET @cMonth = SUBSTRING(@cSerialNo, 9, 2) 
      SET @cYear  = '20' + SUBSTRING(@cSerialNo, 11, 2) 
   END 
   ELSE IF @nStrLength = 14 
   BEGIN
      --  If the first character starts with "C" or "N" digit 
      IF LEFT(@cSerialNo, 1) IN ('C', 'N') 
      BEGIN
         SET @cYear  = SUBSTRING(@cSerialNo, 9, 4) 
         SET @cMonth = SUBSTRING(@cSerialNo, 13, 2) 
      END
      ELSE
      BEGIN -- Begin 1st Character Not In ('C', 'N')

         SET @cYear  = SUBSTRING(@cSerialNo, 8, 4) 
         SET @cMonth = SUBSTRING(@cSerialNo, 12, 2)             

         IF ISDATE( dbo.fnc_RTrim(@cYear) + dbo.fnc_RTrim(@cMonth) + '01' ) = 0 
         BEGIN 
            SET @cYear  = SUBSTRING(@cSerialNo, 9, 4) 
            SET @cMonth = SUBSTRING(@cSerialNo, 13, 2) 
         END
         ELSE 
         IF CAST(@cYear as int) - DatePart(year, getdate()) > 10 
         BEGIN 
            SET @cYear  = SUBSTRING(@cSerialNo, 9, 4) 
            SET @cMonth = SUBSTRING(@cSerialNo, 13, 2)            
         END 
      END -- End 1st Character Not In ('C', 'N')
   END 
   ELSE
   BEGIN
      SET @nErr = 61001
      SET @cErrmsg = 'Invalid Serial No. Number of Characters Should be equal to 12, 14 or 16.'
      SET @bSuccess = 0 
      GOTO QUIT           
   END

   SET @cExpiryDate = dbo.fnc_RTrim(@cYear) + dbo.fnc_RTrim(@cMonth) + '01'
   IF ISDATE( @cExpiryDate ) = 0 
   BEGIN
      SET @nErr = 61002
      SET @cErrmsg = dbo.fnc_RTrim(@cExpiryDate) + ' Is Not valid Date Format' 
      SET @bSuccess = 0 
      GOTO QUIT       
   END 

   IF @bSuccess = 1
   BEGIN
      SET @cErrmsg = 'Converted Date: ' + dbo.fnc_RTrim(@cExpiryDate)
   END 

   -- Validate the PickDetail Here 
   IF dbo.fnc_RTrim(@cOrderKey) IS NOT NULL AND dbo.fnc_RTrim(@cOrderKey) <> '' 
   BEGIN
      IF NOT EXISTS(SELECT 1 
                    FROM PICKDETAIL (NOLOCK)
                    JOIN LOTATTRIBUTE (NOLOCK) ON PICKDETAIL.LOT = LOTATTRIBUTE.LOT 
                    WHERE PICKDETAIL.OrderKey = @cOrderKey 
                    AND   PICKDETAIL.StorerKey = @cStorerKey 
                    AND   PICKDETAIL.SKU = @cSKU 
                    AND   LOTATTRIBUTE.Lottable04 = @cExpiryDate )
      BEGIN
         SET @nErr = 61003
         SET @cErrmsg = 'Expiry Date does not match with the Pick Slip. Please check! ' 
         SET @bSuccess = 0 
         GOTO QUIT    
      END 
   END

QUIT:   
END


GO