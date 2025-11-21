SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: ispExpDateValidation_Wrapper                       */  
/* Creation Date: 12-Oct-2006                                           */  
/* Copyright: IDS                                                       */  
/* Written by: Vicky                                                    */  
/*                                                                      */  
/* Purpose: Generic ExpiryDate Validation                               */  
/*                                                                    */  
/*                                                                      */  
/* Called By: From Pick & Pack Maintenance Screen                       */  
/*                                                                      */  
/* PVCS Version: 1.0                                                   */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author     Purposes                                     */  
/* 2008/3/7     TTL        SOS86428                                     */  
/*                         IF StorerConfig not setup, then do not check. */
/************************************************************************/  
CREATE PROC [dbo].[ispExpDateValidation_Wrapper] (  
   @cPickSlipNo NVARCHAR(10),   
   @cStorerKey  NVARCHAR(15),   
   @cSKU        NVARCHAR(20),  
   @cExpiryDate NVARCHAR(18),   
   @bSuccess    int = 1 OUTPUT,  
   @nErr        int = 0 OUTPUT,  
   @cErrmsg     NVARCHAR(250) = '' OUTPUT )  
AS   
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF 
   
   DECLARE   
   @cChkExpDateSP  NVARCHAR(20),  
   @cLoadKey       NVARCHAR(10),  
   @cOrderKey      NVARCHAR(10),  
   @nQty           int,  
   @cPickSlipType  NVARCHAR(10),   
   @cSQLStatement  nvarchar(2000),   
   @cSQLParms      nvarchar(2000)    
  
   SELECT @cLoadKey = ExternOrderKey,  
          @cOrderKey = OrderKey,  
          @cPickSlipType = Zone   
   FROM   PICKHEADER WITH (NOLOCK)  
   WHERE  PickHeaderKey = @cPickSlipNo   
   IF dbo.fnc_RTrim(@cPickSlipType) IS NULL OR dbo.fnc_RTrim(@cPickSlipType) = ''  
   BEGIN  
      SET @bSuccess = -1  
      SET @nErr     = 61566  
      SET @cErrmsg  = 'Unable To Identify Pick Ticket Type.'   
      GOTO QUIT   
   END  
  
   IF @cPickSlipType NOT IN ('XD','LB','LP')   
   BEGIN   
      IF dbo.fnc_RTrim(@cStorerKey) IS NULL OR dbo.fnc_RTrim(@cStorerKey) = ''  
      BEGIN  
         SET ROWCOUNT 1  
  
         SELECT @cStorerKey = STORERKEY  
         FROM   OrderDetail WITH (NOLOCK)  
         WHERE  LoadKey = @cLoadKey   
  
         SET ROWCOUNT 0    
      END   
  
      SELECT @cChkExpDateSP = sValue   
      FROM   StorerConfig WITH (NOLOCK)   
      WHERE  StorerKey = @cStorerKey   
      AND    ConfigKey = 'PnPExpDateCheckCode'   
      IF dbo.fnc_RTrim(@cChkExpDateSP) IS NULL OR dbo.fnc_RTrim(@cChkExpDateSP) = ''  
      BEGIN  
         -- SOS86428 - TTL 2008/3/7 - IF StorerConfig not setup, then do not check. 

            SET @bSuccess = 1
--          SET @bSuccess = -1  
--          SET @nErr     = 61566  
--          SET @cErrmsg  = 'PnPExpDateCheckCode NOT Setup in StorerConfig Table.'   
         GOTO QUIT   
      END  
  
  
      SET @cSQLStatement = N'EXEC ' + dbo.fnc_RTrim(@cChkExpDateSP) +   
          ' @cLoadKey, @cOrderKey ,@cStorerKey, @cSKU, @nQty, @cExpiryDate, @bSuccess OUTPUT, @nErr OUTPUT ' +  
          ', @cErrmsg OUTPUT'   
  
      SET @cSQLParms = N'  @cLoadKey    NVARCHAR(10),  
                           @cOrderKey   NVARCHAR(10),  
                           @cStorerKey  NVARCHAR(15),   
                           @cSKU        NVARCHAR(20),  
                           @nQty        int,  
                           @cExpiryDate NVARCHAR(18),   
                           @bSuccess    int OUTPUT,  
                           @nErr        int OUTPUT,  
                           @cErrmsg     NVARCHAR(250) OUTPUT'  
  
        
      EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,      
             @cLoadKey    
            ,@cOrderKey   
            ,@cStorerKey  
            ,@cSKU        
            ,@nQty        
            ,@cExpiryDate   
            ,@bSuccess OUTPUT  
            ,@nErr OUTPUT       
            ,@cErrmsg OUTPUT    
  
   END   
  
QUIT:  
END -- procedure  
  
  

GO