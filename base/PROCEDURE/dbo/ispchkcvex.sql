SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispChkCVEX                                         */
/* Creation Date: 12-Oct-2006                                           */
/* Copyright: IDS                                                       */
/* Written by: Vicky                                                    */
/*                                                                      */
/* Purpose: SOS#50956 - Ciba Vision Serial # Validation for Trial Lens  */
/*                                                                   	*/
/*                                                                      */
/* Called By: ispExpDateValidation_Wrapper base on StorerConfig.sValue  */
/*            Storerconfig = PnPExpDateCheckCode                        */ 
/*                                                                      */
/* Parameters:  @cExpiryDate is in the format of DDMMYYYY               */
/*                                                                      */
/* PVCS Version: 1.0	                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 16-Jan-2007  Vicky      Add in checking for Either ExpDate/SerialNo  */
/************************************************************************/

CREATE PROC [dbo].[ispChkCVEX] (
   @cLoadKey    NVARCHAR(10),
   @cOrderKey   NVARCHAR(10),
   @cStorerKey  NVARCHAR(15), 
   @cSKU        NVARCHAR(20),
   @nQty        int,
   @cExpiryDate NVARCHAR(18), 
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
     ,@cDay            NVARCHAR(2) 
     ,@cSKUGroup       NVARCHAR(10)
     ,@cSerialNo       NVARCHAR(18)
     ,@cSQLStatement   nvarchar(2000)
     ,@cSQLParms       nvarchar(2000)  
     ,@cChkExpDateSP   NVARCHAR(20)


   SET @bSuccess = 1
   SET @cMonth = ''
   SET @cYear  = '' 
   SET @cDay = ''
   SET @cChkExpDateSP = 'ispChkCVSN'
   
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@cExpiryDate)) IS NULL OR dbo.fnc_LTrim(dbo.fnc_RTrim(@cExpiryDate)) = '' 
   BEGIN
      SET @cErrmsg = 'Blank Expiry Date / Serial No' -- 16-Jan-2007
      SET @bSuccess = 0 
      GOTO QUIT 
   END 

   SET @cExpiryDate = ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@cExpiryDate)), '')
   SET @nStrLength = LEN(@cExpiryDate)

   IF @nStrLength = 8
   BEGIN
 
    SET @cYear  = SUBSTRING(@cExpiryDate, 5, 4) 
    SET @cMonth = SUBSTRING(@cExpiryDate, 3, 2)             
    SET @cDay   = SUBSTRING(@cExpiryDate, 1, 2)   
   
    SET @cExpiryDate = dbo.fnc_RTrim(@cYear) + dbo.fnc_RTrim(@cMonth) + dbo.fnc_RTrim(@cDay)   

	  IF ISDATE( @cExpiryDate ) = 0 
	  BEGIN
		   SET @nErr = 62002
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
                    FROM PICKDETAIL WITH (NOLOCK)
                    JOIN LOTATTRIBUTE WITH (NOLOCK) ON PICKDETAIL.LOT = LOTATTRIBUTE.LOT 
                    WHERE PICKDETAIL.OrderKey = @cOrderKey 
                    AND   PICKDETAIL.StorerKey = @cStorerKey 
                    AND   PICKDETAIL.SKU = @cSKU 
                    AND   LOTATTRIBUTE.Lottable04 = @cExpiryDate )
      BEGIN
         SET @nErr = 62003
         SET @cErrmsg = 'Expiry Date does not match with the Pick Slip. Please check! ' 
         SET @bSuccess = 0 
         GOTO QUIT    
      END 
    END
 END -- Length = 8 (DDMMYYYY)
 ELSE 
 BEGIN --16-Jan-2007
      SELECT @cSerialNo = @cExpiryDate

      SET @cSQLStatement = N'EXEC ' + dbo.fnc_RTrim(@cChkExpDateSP) + 
          ' @cLoadKey, @cOrderKey ,@cStorerKey, @cSKU, @nQty, @cSerialNo, @bSuccess OUTPUT, @nErr OUTPUT ' +
          ', @cErrmsg OUTPUT' 

      SET @cSQLParms = N'  @cLoadKey    NVARCHAR(10),
                           @cOrderKey   NVARCHAR(10),
                           @cStorerKey  NVARCHAR(15), 
                           @cSKU        NVARCHAR(20),
                           @nQty        int,
                           @cSerialNo   NVARCHAR(18), 
                           @bSuccess    int OUTPUT,
                           @nErr        int OUTPUT,
                           @cErrmsg     NVARCHAR(250) OUTPUT'

      
      EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,    
             @cLoadKey  
            ,@cOrderKey 
            ,@cStorerKey
            ,@cSKU      
            ,@nQty      
            ,@cSerialNo 
            ,@bSuccess OUTPUT
            ,@nErr OUTPUT     
            ,@cErrmsg OUTPUT  
 END  

QUIT:   
END


GO