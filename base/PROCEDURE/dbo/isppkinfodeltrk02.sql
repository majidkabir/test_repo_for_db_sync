SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: ispPKINFODELTRK02                                  */  
/* Creation Date: 16-Aug-2021                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-17693 - CN SKE Delete Tracking Number                   */     
/*                                                                      */  
/* Called By: isp_PackinfoGenTrackingNo_Wrapper from Packdetail Trigger */  
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */    
/* Date         Author   Ver  Purposes                                  */    
/************************************************************************/  
CREATE PROC [dbo].[ispPKINFODELTRK02] 
       @c_Pickslipno                NVARCHAR(10)  
     , @n_CartonNo                  INT  
     , @c_TrackingNo                NVARCHAR(40)  
     , @b_Success                   INT           OUTPUT    
     , @n_Err                       INT           OUTPUT     
     , @c_ErrMsg                    NVARCHAR(250) OUTPUT    
AS     
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
       
   DECLARE @n_Continue      INT,  
           @n_StartTCnt     INT,  
           @c_Type          NVARCHAR(10),  
           @c_Storerkey     NVARCHAR(15),  
           @c_Orderkey      NVARCHAR(10),  
           @n_RowRef        BIGINT,
           @c_Loadkey       NVARCHAR(10),
           @c_Shipperkey    NVARCHAR(15),
           @c_OrdType       NVARCHAR(10) 
                                               
   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1, @n_RowRef = 0  
    
   --Validation  
   IF ISNULL(@c_TrackingNo,'') = ''    
   BEGIN         
      GOTO QUIT_SP  
   END  
    
  --Reverse cartontrack   
   IF @n_continue IN (1,2)  
   BEGIN  
      --Discrete
      SELECT TOP 1 @c_OrderKey   = OH.Orderkey
                 , @c_Type       = OH.DocType 
                 , @c_Storerkey  = OH.Storerkey
                 , @c_Shipperkey = OH.ShipperKey
                 , @c_OrdType    = OH.[Type]
      FROM PACKHEADER PH (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PH.OrderKey
      WHERE PH.PickSlipNo = @c_Pickslipno

      --Conso
      IF ISNULL(@c_OrderKey,'') = ''
      BEGIN
         SELECT TOP 1 @c_OrderKey   = OH.Orderkey
                    , @c_Type       = OH.DocType 
                    , @c_Storerkey  = OH.Storerkey
                    , @c_Shipperkey = OH.ShipperKey
                    , @c_OrdType    = OH.[Type]
         FROM PICKHEADER PH (NOLOCK)
         JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.LoadKey = PH.ExternOrderKey
         JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
         WHERE PH.Pickheaderkey = @c_Pickslipno
      END   

      SELECT TOP 1 @n_RowRef = CT.RowRef  
      FROM CARTONTRACK CT (NOLOCK)  
      JOIN CODELKUP CL (NOLOCK) ON CT.Carriername = CL.code2 AND CT.KeyName = CL.UDF02 
      WHERE CL.Listname = 'AUTOPKINFO'  
      AND CL.Storerkey = @c_Storerkey  
      AND CL.code = @c_Type  
      AND CL.code2 = @c_Shipperkey
      AND CT.CarrierRef2 = 'GET'  
      AND CT.TrackingNo = @c_TrackingNo   
      ORDER BY CT.RowRef                        
       
      IF @n_RowRef > 0  
      BEGIN  
         UPDATE CARTONTRACK WITH (ROWLOCK)  
         SET CarrierRef2 = '',  
             LabelNo     = '',  
             ArchiveCop  = NULL,
             EditWho     = SUSER_SNAME(),
             EditDate    = GETDATE()
         WHERE RowRef = @n_RowRef  
           
         SELECT @n_err = @@ERROR  
              
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 61810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg="NSQL"+CONVERT(char(5), @n_err)+": Update Failed On CARTONTRACK Table. (ispPKINFODELTRK02)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "  
         END                          
      END       
   END  
                   
   QUIT_SP:    
   IF @n_Continue=3  -- Error Occured - Process AND Return  
   BEGIN  
      SELECT @b_Success = 0  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispPKINFODELTRK02'    
      --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END  
END    

GO