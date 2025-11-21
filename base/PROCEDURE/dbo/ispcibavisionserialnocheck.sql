SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
--
-- Definition for stored procedure ispCibaVisionSerialNoCheck : 
--

CREATE PROC [dbo].[ispCibaVisionSerialNoCheck] (
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

   DECLARE 
      @cStrLength      int
     ,@cMonth          NVARCHAR(2)
     ,@cYear           NVARCHAR(4) 
     ,@cSKUGroup       NVARCHAR(10) 


   SET @bSuccess = 1
   SET @cMonth = ''
   SET @cYear  = '' 
   
   IF dbo.fnc_LTRIM(dbo.fnc_RTRIM(@cSerialNo)) IS NULL OR dbo.fnc_LTRIM(dbo.fnc_RTRIM(@cSerialNo)) = '' 
   BEGIN
      SET @cErrmsg = 'Blank Serial No' 
      SET @bSuccess = 0 
      GOTO QUIT 
   END 

   SET @cSerialNo = ISNULL(dbo.fnc_LTRIM(dbo.fnc_RTRIM(@cSerialNo)), '')
   SET @cStrLength = @cSerialNo 

   IF @cStrLength = 12 OR @cStrLength = 16 
   BEGIN   
      SET @cMonth = SUBSTRING(@cSerialNo, 9, 2) 
      SET @cYear  = '20' + SUBSTRING(@cSerialNo, 11, 2) 
   END 
   ELSE IF @cStrLength = 14 
   BEGIN
      --  If the first character starts with "C" or "N" digit 
      IF LEFT(@cSerialNo, 1) IN ('C', 'N')
      BEGIN
         SET @cYear  = SUBSTRING(@cSerialNo, 9, 4) 
         SET @cMonth = SUBSTRING(@cSerialNo, 13, 2) 
      END
      ELSE
      BEGIN -- Begin 1st Character Not In ('C', 'N')
         SET @cSKUGroup = ''

         SELECT @cSKUGroup = ISNULL(SKU.SKUGROUP, '')  
         FROM   SKU (NOLOCK) 
         WHERE  StorerKey = @cStorerKey
         AND    SKU = @cSKU 

         IF @cSKUGroup IN ('CVIS','CWJG','DD30','DG30','DP30','DT30','DV3',
                           'DV90','DV5B','HFOM','HFPM','HFTM','SFO2','SFND',
                           'SFND3','TD3') 
         BEGIN
            SET @cYear  = SUBSTRING(@cSerialNo, 8, 4) 
            SET @cMonth = SUBSTRING(@cSerialNo, 12, 2)             
         END 
         ELSE IF @cSKUGroup IN ('C2BG','C2BL','C2BW','C2BY','C2OB','C2OG','C2OH','C2OY',
                                'C3BB','C3BG','C3BH','C3BL','C3BT','C3BY','C3CB','C3CG',
                                'C3CU','C3CV','C3CW','C3CY','C3OA','C3OB','C3OE','C3OH',
                                'C3OJ','C3OS','C3OV','C3OW','C3OY','CVTS','CWEY','CWRH',
                                'CWWO','CWZB')
         BEGIN
            SET @cYear  = SUBSTRING(@cSerialNo, 9, 4) 
            SET @cMonth = SUBSTRING(@cSerialNo, 13, 2)             
         END 
         ELSE
         BEGIN
            SET @cErrmsg = 'SKU Group UnMatch, Please check your SKUGroup in SKU Master' 
            SET @bSuccess = 0 
            GOTO QUIT 
         END 
      END -- End 1st Character Not In ('C', 'N')
   END 
   IF ISDATE( @cYear + @cMonth + '01' ) = 0 
   BEGIN
      SET @cErrmsg = @cYear + @cMonth + '01' + ' Is Not valid Date Format' 
      SET @bSuccess = 0 
      GOTO QUIT       
   END 

   -- Validate the PickDetail Here 
   
QUIT:   
END

GO