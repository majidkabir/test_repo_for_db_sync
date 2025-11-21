SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: ispCTNLBLITF05                                     */  
/* Creation Date: 28-Jun-2022                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-20092 - [CN]MAST_NORMAL_close carton_TRIGGER_OUT        */  
/*                                                                      */  
/* Called By: isp_PrintCartonLabel_Interface                            */  
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 28-Jun-2022 WLChooi  1.0   DevOps Combine Script                     */
/************************************************************************/  
CREATE PROCEDURE [dbo].[ispCTNLBLITF05]  
      @c_Pickslipno   NVARCHAR(10)       
  ,   @n_CartonNo_Min INT   
  ,   @n_CartonNo_Max INT   
  ,   @b_Success      INT           OUTPUT    
  ,   @n_Err          INT           OUTPUT    
  ,   @c_ErrMsg       NVARCHAR(255) OUTPUT  
     
AS    
BEGIN    
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
        
   DECLARE @n_continue  INT  
         , @n_starttcnt INT  
         , @c_trmlogkey NVARCHAR(10)  
         , @c_DocType   NVARCHAR(50) 
         , @n_Cartonno  INT
         , @c_Storerkey NVARCHAR(15)
         , @c_OrderKey  NVARCHAR(10)
         , @c_LabelNo   NVARCHAR(50)
     
   DECLARE @c_PrintCartonLabelByITF   NVARCHAR(100)  
         , @c_Option1                 NVARCHAR(255)  
         , @c_Option2                 NVARCHAR(255)  
         , @c_Option3                 NVARCHAR(255)  
                                                                                                 
   SET @n_err = 0  
   SET @b_success = 1  
   SET @c_errmsg = ''  
   SET @n_continue = 1  
   SET @n_starttcnt = @@TRANCOUNT  
   SET @n_Cartonno = 1  

   SELECT @c_Storerkey  = ORDERS.StorerKey  
        , @c_OrderKey   = ORDERS.OrderKey    
        , @c_DocType    = ORDERS.Doctype
   FROM PACKHEADER (NOLOCK)  
   JOIN ORDERS (NOLOCK) ON PACKHEADER.Orderkey = ORDERS.Orderkey  
   WHERE PACKHEADER.PickSlipNo = @c_PickSlipNo  
   
   IF ISNULL(@c_OrderKey,'') = ''
   BEGIN
      SELECT TOP 1 @c_Storerkey  = ORDERS.StorerKey  
                 , @c_OrderKey   = ORDERS.OrderKey    
                 , @c_DocType    = ORDERS.Doctype
      FROM PACKHEADER (NOLOCK)  
      JOIN LOADPLANDETAIL (NOLOCK) ON LOADPLANDETAIL.LoadKey = PACKHEADER.LoadKey
      JOIN ORDERS (NOLOCK) ON LOADPLANDETAIL.Orderkey = ORDERS.Orderkey  
      WHERE PACKHEADER.PickSlipNo = @c_PickSlipNo 
   END

   IF ISNULL(@c_DocType,'') <> 'N'
      GOTO QUIT_SP

   IF @n_CartonNo_Min = @n_CartonNo_Max  
   BEGIN  
      SET @n_Cartonno = @n_CartonNo_Min  
   END  
   ELSE  
   BEGIN  
      SELECT @n_CartonNo = MAX(PD.Cartonno)  
      FROM PACKDETAIL PD (NOLOCK)
      WHERE PD.PickSlipNo = @c_Pickslipno  
   END  

   SELECT @c_LabelNo = PD.LabelNo
   FROM PACKDETAIL PD (NOLOCK)
   WHERE PD.PickSlipNo = @c_Pickslipno 
   AND PD.CartonNo = @n_Cartonno

   EXEC nspGetRight   
      '',    
      @c_StorerKey,                
      '',                      
      'PrintCartonLabelByITF',   
      @b_success               OUTPUT,  
      @c_PrintCartonLabelByITF OUTPUT,  
      @n_err                   OUTPUT,  
      @c_errmsg                OUTPUT,  
      @c_Option1               OUTPUT,  
      @c_Option2               OUTPUT,  
      @c_Option3               OUTPUT  
  
   IF @c_PrintCartonLabelByITF = '1'  
   BEGIN  
      SELECT @b_success = 1      
      EXECUTE nspg_getkey      
            'TransmitlogKey2'      
          , 10      
          , @c_trmlogkey OUTPUT      
          , @b_success   OUTPUT      
          , @n_err       OUTPUT      
          , @c_errmsg    OUTPUT      
             
      IF @b_success <> 1      
      BEGIN      
         SELECT @n_continue = 3      
      END      
      ELSE      
      BEGIN      
         INSERT INTO Transmitlog2 (transmitlogkey, tablename, key1, key2, key3, transmitflag, TransmitBatch)      
         VALUES (@c_trmlogkey, @c_Option1, @c_PickSlipNo, @c_LabelNo, @c_Storerkey, '0', '')      
      END    
   END          

   IF @c_errmsg = ''
      SET @c_errmsg = 'CONTINUE PRINT'
 
QUIT_SP:  
   IF @n_continue = 3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0       
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt   
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE   
      BEGIN  
         WHILE @@TRANCOUNT > @n_starttcnt   
         BEGIN  
            COMMIT TRAN  
         END            
      END  
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispCTNLBLITF05'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE   
   BEGIN  
      SELECT @b_success = 1  
      WHILE @@TRANCOUNT > @n_starttcnt   
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END    
END

GO