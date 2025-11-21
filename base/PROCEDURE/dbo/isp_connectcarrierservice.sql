SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_ConnectCarrierService                          */  
/* Creation Date: 15-Dec-2011                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose: Carrier Service - Cancel Shipment                           */  
/*                                                                      */  
/* Called By: Carrier Service - Shipment Cancel                         */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 10-01-2012   ChewKP  1.1   Standardize ConsoOrderKey Mapping         */
/*                            (ChewKP01)                                */
/* 10-01-2012   James   1.2   Put in RDT compatible msg (james01)       */
/* 21-01-2012   NJOW01  1.3   Not to connect Fedex Web Service when     */
/*                            ConnectFedexService is turned off         */
/* 09-02-2012   Chee    1.4   Change CODELKUP.LISTNAME reference FROM   */
/*                            FEDEXACCNO to CARRIERACC (Chee01)         */
/************************************************************************/   
CREATE PROCEDURE [dbo].[isp_ConnectCarrierService]  
         @c_PickSlipNo     NVARCHAR(10) = '' 
        ,@n_CartonNo       INT    
        ,@c_LabelNo        NVARCHAR(20)
        ,@c_TrackingNumber NVARCHAR(20) = ''
        ,@c_CarrierService NVARCHAR(10)    
        ,@b_Success        INT               OUTPUT 
        ,@n_err            INT               OUTPUT
        ,@c_errmsg         NVARCHAR(250)      OUTPUT           

AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @b_debug                    INT
         , @n_Continue                 INT
         , @c_StorerKey                NVARCHAR(15)
         , @c_Configkey                NVARCHAR(30)
         , @c_SValue                   NVARCHAR(10)
         , @c_UserCrendentialKey       NVARCHAR(30)    
         , @c_UserCredentialPassword   NVARCHAR(30)    
         , @c_ClientAccountNumber      NVARCHAR(18)    
         , @c_ClientMeterNumber        NVARCHAR(18)
         , @c_UspsApplicationId        NVARCHAR(30)  
         , @c_ServiceType              NVARCHAR(30)
         , @c_EDI_ServiceType          NVARCHAR(18)    
         , @cLangCode	               NVARCHAR( 3) 

   DECLARE @n_IsRDT INT
   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

   SET @b_debug                  = 0
   SET @n_err                    = 0
   SET @b_success                = 1
   SET @c_errmsg                 = ''

   SET @n_continue               = 1
   SET @c_StorerKey              = ''
   SET @c_Configkey              = 'ConnectFedexService'
   SET @c_SValue                 = ''
   SET @c_UserCrendentialKey     = ''
   SET @c_UserCredentialPassword = ''
   SET @c_ClientAccountNumber    = ''
   SET @c_ClientMeterNumber      = ''
   SET @c_UspsApplicationId      = ''
   SET @c_ServiceType            = ''
   SET @c_EDI_ServiceType        = ''

   IF @c_CarrierService <> 'X' GOTO QUIT_SP

   IF @c_TrackingNumber = ''
   BEGIN
      SELECT TOP 1 @c_StorerKey = PH.Storerkey
            ,@c_ClientAccountNumber = OH.M_Fax1
            ,@c_EDI_ServiceType = OH.M_Phone2
      FROM PACKHEADER PH WITH (NOLOCK) 
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON ((PH.ConsoOrderKey = OD.consoorderkey AND ISNULL(OD.Consoorderkey,'')<>'') OR PH.Orderkey = OD.Orderkey ) -- (ChewKP01)
      JOIN ORDERS OH WITH (NOLOCK) ON (OD.Orderkey = OH.Orderkey)
      WHERE PH.PickSlipNo = @c_PickSlipNo
   END
   ELSE
   BEGIN
      SELECT TOP 1 @c_StorerKey = PH.Storerkey
                  ,@c_ClientAccountNumber = OH.M_Fax1
                  ,@c_EDI_ServiceType = OH.M_Phone2
      FROM PACKHEADER PH WITH (NOLOCK)  
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON ((PH.ConsoOrderKey = OD.consoorderkey AND ISNULL(OD.Consoorderkey,'')<>'') OR PH.Orderkey = OD.Orderkey ) -- (ChewKP01)
      JOIN ORDERS OH WITH (NOLOCK) ON (OD.Orderkey = OH.Orderkey)
      JOIN PACKDETAIL PD WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)
      WHERE PD.UPC = @c_TrackingNumber
   END

   EXECUTE dbo.nspGetRight NULL                 -- facility
                        ,  @c_Storerkey         -- Storerkey
                        ,  NULL                 -- Sku
                        ,  @c_Configkey         -- Configkey
                        ,  @b_success      OUTPUT
                        ,  @c_SValue       OUTPUT
                        ,  @n_err          OUTPUT
                        ,  @c_errmsg       OUTPUT

   IF @b_success = 0
   BEGIN  
      SET @n_continue = 3 
      IF @n_IsRDT = 0
      BEGIN
         SET @n_Err = 31301
         SEt @c_ErrMsg = 'NSQL' +  CONVERT(VARCHAR(255), @n_Err) 
                    + ': Error Getting StorerCongfig for Storer: ' + @c_Storerkey
                    + '. (isp_ConnectCarrierService)' 
      END
      ELSE
      BEGIN
         SET @n_Err = 71301
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP')
      END
      GOTO QUIT_SP
   END  

   IF @c_SValue <> '1'
   BEGIN
      /*SET @n_continue = 3 
      IF @n_IsRDT = 0
      BEGIN
         SET @c_ErrMsg = CONVERT(VARCHAR(250), @n_Err) 
                    + ': StorerCongfig: ' + RTRIM(@c_Configkey) + ' not setup for Storer: ' + RTRIM(@c_Storerkey)
                    + '. (isp_ConnectCarrierService)' 
      END
      ELSE
      BEGIN
         SET @n_Err = 71302
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP')
      END*/
      GOTO QUIT_SP
   END

   SELECT @c_UserCrendentialKey    = CODELKUP.Long
			,@c_UserCredentialPassword= CONVERT(NVARCHAR(255),CODELKUP.Notes)
			,@c_ClientMeterNumber     = CODELKUP.Short
	FROM CODELKUP WITH (NOLOCK) 
   WHERE CODELKUP.ListName = 'CARRIERACC' --'FEDEXACCNO' Chee01
   AND   CODELKUP.Code = @c_ClientAccountNumber
 
   IF @b_debug = 1 
   BEGIN
      SELECT @c_UserCrendentialKey             
           , @c_UserCredentialPassword        
           , @c_ClientAccountNumber             
           , @c_ClientMeterNumber               
           , @c_TrackingNumber                 
           , @c_UspsApplicationId               
           , @c_ServiceType    
   END

   IF @c_TrackingNumber = ''
   BEGIN
		
      EXEC isp_FedEx_ProcessShipment_Domestic_ExpressOrGround  
              @c_UserCrendentialKey              
            , @c_UserCredentialPassword     
            , @c_ClientAccountNumber           
            , @c_ClientMeterNumber          
            , @c_PickSlipNo                    
            , @n_CartonNo                    
            , @c_LabelNo                    
            , @b_Success                  OUTPUT      
            , @n_err                      OUTPUT      
            , @c_errmsg                   OUTPUT     

      IF @b_success = 0
      BEGIN
         SET @n_continue = 3 
         SET @c_ErrMsg = CONVERT(VARCHAR(255), @n_Err) + '. ' +  @c_errmsg
                       + ' Error Return from isp_FedEx_ProcessShipment_Domestic_ExpressOrGround. (isp_ConnectCarrierService)' 
         GOTO QUIT_SP 
      END

      IF @b_success = 0
      BEGIN
         SET @n_continue = 3
         IF @n_IsRDT = 0
         BEGIN
            SET @c_ErrMsg = CONVERT(VARCHAR(255), @n_Err) + '. ' +  @c_errmsg
                          + ' Error Return from isp_FedEx_ProcessShipment_Domestic_ExpressOrGround_TESTING. (isp_ConnectCarrierService)' 
         END
         ELSE
         BEGIN
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP')
         END
         GOTO QUIT_SP 
      END

   END
   ELSE
   BEGIN
      SELECT @c_ServiceType = ISNULL(RTRIM(Long),'')
      FROM CODELKUP WITH (NOLOCK)
      WHERE ListName = 'FEDEX_EDI'
      AND   CODE = @c_EDI_ServiceType

      EXEC isp_FedEx_DeleteShipment
              @c_UserCrendentialKey             
            , @c_UserCredentialPassword        
            , @c_ClientAccountNumber             
            , @c_ClientMeterNumber               
            , @c_TrackingNumber                 
            , @c_UspsApplicationId               
            , @c_ServiceType                    
            , @b_Success            OUTPUT
            , @n_err                OUTPUT
            , @c_errmsg             OUTPUT

      IF @b_debug = 1 
      BEGIN
         SELECT @b_Success, @n_err, @c_errmsg
      END 

      IF @b_Success = 0
      BEGIN
         SET @n_continue = 3 
         IF @n_IsRDT = 0
         BEGIN
            --SET @n_Err = 31304
            SET @c_ErrMsg = CONVERT(VARCHAR(255), @n_Err) + '. ' + @c_errmsg
                          + ' Error Return from isp_FedEx_DeleteShipment. (isp_ConnectCarrierService)' 
         END
         ELSE
         BEGIN
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP')
         END
         GOTO QUIT_SP 
      END
   END

   QUIT_SP:
   SET @b_success = 1   
   IF @n_continue = 3
   BEGIN
       SET @b_success = 0
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_ConnectCarrierService'  
       --RAISERROR @n_Err @c_ErrMsg
   END
END

GO