SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispSerialNoValidation_Wrapper                      */
/* Creation Date: 25-Sep-2006                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Generic Serial# Validation                                  */
/*                                                                    	*/
/*                                                                      */
/* Called By: From Pick & Pack Maintenance Screen                       */
/*                                                                      */
/* PVCS Version: 1.0  	                                                */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 09-Jul-2013  NJOW    1.0   315487-Extend serialno to char(30)        */
/************************************************************************/
CREATE PROC [dbo].[ispSerialNoValidation_Wrapper] (
   @cPickSlipNo NVARCHAR(10), 
   @cStorerKey  NVARCHAR(15), 
   @cSKU        NVARCHAR(20),
   @cSerialNo   NVARCHAR(30), 
   @bSuccess    int = 1 OUTPUT,
   @nErr        int = 0 OUTPUT,
   @cErrmsg     NVARCHAR(250) = '' OUTPUT )
AS 
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE 
   @cChkSerialNoSP NVARCHAR(20),
   @cLoadKey       NVARCHAR(10),
   @cOrderKey      NVARCHAR(10),
   @nQty           int,
   @cPickSlipType  NVARCHAR(10), 
   @cSQLStatement  nvarchar(2000), 
   @cSQLParms      nvarchar(2000)  

   SELECT @cLoadKey = ExternOrderKey,
          @cOrderKey = OrderKey,
          @cPickSlipType = Zone 
   FROM   PICKHEADER (NOLOCK)
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
         FROM   OrderDetail (NOLOCK)
         WHERE  LoadKey = @cLoadKey 

         SET ROWCOUNT 0  
      END 

      SELECT @cChkSerialNoSP = sValue 
      FROM   StorerConfig (NOLOCK) 
      WHERE  StorerKey = @cStorerKey 
      AND    ConfigKey = 'PnPSerialNoCheckCode' 
      IF dbo.fnc_RTrim(@cChkSerialNoSP) IS NULL OR dbo.fnc_RTrim(@cChkSerialNoSP) = ''
      BEGIN
         SET @bSuccess = -1
         SET @nErr     = 61566
         SET @cErrmsg  = 'PnPSerialNoCheckCode NOT Setup in StorerConfig Table.' 
         GOTO QUIT 
      END


      SET @cSQLStatement = N'EXEC ' + dbo.fnc_RTrim(@cChkSerialNoSP) + 
          ' @cLoadKey, @cOrderKey ,@cStorerKey, @cSKU, @nQty, @cSerialNo, @bSuccess OUTPUT, @nErr OUTPUT ' +
          ', @cErrmsg OUTPUT' 

      SET @cSQLParms = N'  @cLoadKey    NVARCHAR(10),
                           @cOrderKey   NVARCHAR(10),
                           @cStorerKey  NVARCHAR(15), 
                           @cSKU        NVARCHAR(20),
                           @nQty        int,
                           @cSerialNo   NVARCHAR(30), 
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
END -- procedure



GO