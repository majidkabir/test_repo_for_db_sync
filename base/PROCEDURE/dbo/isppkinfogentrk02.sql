SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: ispPKINFOGENTRK02                                  */  
/* Creation Date: 16-Aug-2021                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-17693 - CN SKE Generate Tracking Number                 */     
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
/* 2021-09-03   WLChooi  1.1  WMS-17693 - Exclude ECOM Orders (WL01)    */
/* 2021-09-06   WLChooi  1.2  Bug Fix For Conso Packing (WL02)          */   
/************************************************************************/  
CREATE PROC [dbo].[ispPKINFOGENTRK02]
       @c_Pickslipno                NVARCHAR(10)  
     , @n_CartonNo                  INT  
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
           @c_TrackingNo    NVARCHAR(40),  
           @c_Orderkey      NVARCHAR(4000),   --WL02
           @n_RowRef        BIGINT,
           @c_Loadkey       NVARCHAR(10),
           @c_Shipperkey    NVARCHAR(15),
           @c_LabelNo       NVARCHAR(20),
           @c_OrdType       NVARCHAR(10),
           @b_Debug         INT = 0
   
   IF @n_Err > 0
   BEGIN
      SET @b_Debug = @n_Err
   END                                            
   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1  
     
   --Validation  
   IF EXISTS(SELECT 1 FROM PACKINFO (NOLOCK)   
             WHERE PickslipNo = @c_Pickslipno  
             AND CartonNo = @n_Cartonno  
             AND ISNULL(TrackingNo,'') <> '')  
   BEGIN         
      GOTO QUIT_SP  
   END  
   
   SELECT @c_LabelNo = LabelNo
   FROM PACKDETAIL (NOLOCK)
   WHERE PickSlipNo = @c_Pickslipno
   AND CartonNo = @n_CartonNo
     
   --Get tracking number  
   IF @n_continue IN(1,2)  
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
         SELECT TOP 1 @c_OrderKey   = ''   --CT.Orderkey   --WL02
                    , @c_Type       = OH.DocType 
                    , @c_Storerkey  = OH.Storerkey
                    , @c_Shipperkey = OH.ShipperKey
                    , @c_OrdType    = OH.[Type]
         FROM PACKHEADER PH (NOLOCK)
         JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.LoadKey = PH.LoadKey
         JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
         --CROSS APPLY (SELECT TOP 1 CTNTR.CarrierRef1 AS Orderkey 
         --             FROM CARTONTRACK CTNTR (NOLOCK)
         --             WHERE CTNTR.KeyName = 'WSSOTMSCR2' AND CTNTR.CarrierRef1 = OH.OrderKey
         --             AND (CTNTR.TrackingNo IS NOT NULL AND CTNTR.TrackingNo <> '') ) AS CT   --WL02
         WHERE PH.PickSlipNo = @c_Pickslipno

         --WL02 S
         SELECT @c_OrderKey = STUFF((SELECT ',' + RTRIM(OH.OrderKey) 
                                     FROM PACKHEADER PH (NOLOCK)
                                     JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.LoadKey = PH.LoadKey
                                     JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
                                     WHERE PH.PickSlipNo = @c_Pickslipno
                                     ORDER BY 1 FOR XML PATH('')),1,1,'' )
         --WL02 E
      END 

      --WL01 S
      IF ISNULL(@c_OrderKey,'') = ''
      BEGIN
         SELECT TOP 1 @c_OrderKey   = OH.Orderkey
                    , @c_Type       = OH.DocType 
                    , @c_Storerkey  = OH.Storerkey
                    , @c_Shipperkey = OH.ShipperKey
                    , @c_OrdType    = OH.[Type]
         FROM PACKHEADER PH (NOLOCK)
         JOIN PACKTASK PT (NOLOCK) ON PT.TaskBatchNo = PH.TaskBatchNo
         JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PT.OrderKey
         WHERE PH.PickSlipNo = @c_Pickslipno
      END
      --WL01 E

      IF ISNULL(@c_OrderKey,'') = ''
         GOTO QUIT_SP
      
      --B2B only get trackingno for SF
      IF @c_Type = 'N' AND @c_Shipperkey <> 'SF'
         GOTO QUIT_SP
      
      --WL01 S
      IF @c_Type = 'E'
         GOTO QUIT_SP

      --B2C - No need to generate TrackingNo for Cartonno 1, directly get from ORDERS.UserDefine04 / ORDERS.TrackingNo
      --IF @c_Type = 'E' AND @n_CartonNo = 1
      --BEGIN
      --   IF EXISTS (SELECT 1 FROM ORDERS (NOLOCK) WHERE Orderkey = @c_Orderkey AND UserDefine04 <> '')
      --   BEGIN
      --      SELECT @c_TrackingNo = OH.UserDefine04
      --      FROM ORDERS OH (NOLOCK)
      --      WHERE OH.OrderKey = @c_Orderkey
      --   END
      --   ELSE
      --   BEGIN
      --      SELECT @c_TrackingNo = OH.TrackingNo
      --      FROM ORDERS OH (NOLOCK)
      --      WHERE OH.OrderKey = @c_Orderkey
      --   END

      --   GOTO SKIP_CT
      --END
      --WL01 E

      IF @b_Debug = 1
         SELECT @c_Storerkey, @c_Type, @c_Shipperkey, @c_OrderKey

      SELECT TOP 1 @c_TrackingNo = CT.TrackingNo,  
                   @n_RowRef     = CT.RowRef  
      FROM CARTONTRACK CT (NOLOCK)  
      JOIN CODELKUP CL (NOLOCK) ON CT.Carriername = CL.code2 AND CT.KeyName = CL.UDF02    
      WHERE CL.Listname = 'AUTOPKINFO'  
      AND CL.Storerkey = @c_Storerkey  
      AND CL.code = @c_Type  
      AND CL.code2 = @c_Shipperkey
      AND CT.CarrierRef1 in (SELECT ColValue from dbo.fnc_delimsplit (',',@c_OrderKey))   --@c_OrderKey   --WL02
      AND CT.CarrierRef2 = ''  
      AND (CT.LabelNo IS NULL OR CT.LabelNo = '')
      ORDER BY CT.RowRef                        
        
      IF ISNULL(@c_TrackingNo,'') = ''  
      BEGIN  
          SET @n_continue = 3      
          SET @n_err = 61800-- Should Be Set To The SQL Errmessage but I don't know how to do so.   
          SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Unable to get tracking number. (ispPKINFOGENTRK02)'        
      END  
   END  

   SKIP_CT:
   IF @b_Debug = 1
         SELECT @c_TrackingNo

   --Update tracking number to packinfo  
   IF @n_continue IN(1,2)  
   BEGIN  
      IF EXISTS(SELECT 1 FROM PACKINFO (NOLOCK)   
                WHERE PickslipNo = @c_Pickslipno  
                AND CartonNo = @n_CartonNo)  
      BEGIN  
         UPDATE PACKINFO WITH (ROWLOCK)  
         SET TrackingNo = @c_TrackingNo,  
             TrafficCop = NULL  
        WHERE PickslipNo = @c_Pickslipno  
         AND CartonNo = @n_CartonNo          
            
         SELECT @n_err = @@ERROR  
            
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 61810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg="NSQL"+CONVERT(char(5), @n_err)+": Update Failed On PACKINFO Table. (ispPKINFOGENTRK02)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "  
         END         
      END          
      ELSE  
      BEGIN  
        INSERT INTO PACKINFO (Pickslipno, Cartonno, TrackingNo)  
        VALUES (@c_Pickslipno, @n_CartonNo, @c_TrackingNo)  
   
          SELECT @n_err = @@ERROR  
            
          IF @n_err <> 0  
          BEGIN  
              SELECT @n_continue = 3  
              SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 61820   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
              SELECT @c_errmsg="NSQL"+CONVERT(char(5), @n_err)+": Insert Failed On PACKINFO Table. (ispPKINFOGENTRK02)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "  
          END         
      END  
   END  
     
   --Update carton track  
   IF @n_continue IN(1,2)  
   BEGIN  
      UPDATE CARTONTRACK WITH (ROWLOCK)  
      SET CarrierRef2 = 'GET',  
          LabelNo = @c_LabelNo  
      WHERE RowRef = @n_RowRef  
   
       SELECT @n_err = @@ERROR  
            
       IF @n_err <> 0  
       BEGIN  
           SELECT @n_continue = 3  
           SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 61820   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
           SELECT @c_errmsg="NSQL"+CONVERT(char(5), @n_err)+": Update Failed On CARTONTRACK Table. (ispPKINFOGENTRK02)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "  
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
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispPKINFOGENTRK02'    
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