SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_GLBL09                                          */
/* Creation Date: 01-Aug-2016                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: SOS#371502 - CN-LBI MAST VSBA                               */ 
/*                                                                      */
/* Input Parameters:  @c_PickSlipNo-Pickslipno, @n_CartonNo - CartonNo  */
/*                    storerconfig: GenLabelNo_SP                       */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage: Call from isp_GenLabelNo_Wrapper                              */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 02-SEP-2016  NJOW01  1.0   376168-Change lable no from 20 to 16 len  */      
/* 05-SEP-2018  Wan01   1.1   PerFormance Tune                          */
/* 23-OCT-2019  WLChooi 1.2   WMS-10936 - Modify Logic (WL01)           */
/* 03-Nov-2020  WLChooi 1.3   Performance Tuning (WL02)                 */
/************************************************************************/

CREATE PROC [dbo].[isp_GLBL09] ( 
         @c_PickSlipNo   NVARCHAR(10) 
      ,  @n_CartonNo     INT
      ,  @c_LabelNo      NVARCHAR(20)   OUTPUT )
AS
BEGIN
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
      
   DECLARE @n_StartTCnt          INT
         , @n_Continue           INT
         , @b_Success            INT 
         , @n_Err                INT  
         , @c_ErrMsg             NVARCHAR(255)
         
   DECLARE @c_Label_SeqNo  NVARCHAR(10)
          ,@c_Consigneekey NVARCHAR(15)
          ,@c_Storerkey    NVARCHAR(15)
          ,@c_Keyname      NVARCHAR(18)      
          
          ,@c_Orderkey     NVARCHAR(10) --(Wan01) 
          ,@c_Loadkey      NVARCHAR(10) --(Wan01)
          

   SET @n_StartTCnt        = @@TRANCOUNT
   SET @n_Continue         = 1
   SET @b_Success          = 0
   SET @n_Err              = 0
   SET @c_ErrMsg           = ''
   
   --(Wan01) - START
   SET @c_Orderkey = ''
   SET @c_Loadkey  = ''
   
   SELECT @c_Orderkey = PH.Orderkey
         ,@c_Loadkey  = PH.ExternOrderKey
   FROM PICKHEADER PH WITH (NOLOCK)
   WHERE PH.PickHeaderKey = @c_PickSlipNo
   
   IF @c_Orderkey = ''
   BEGIN
   	--WL02 START
      /*SELECT TOP 1 
          @c_Consigneekey = O.Consigneekey
         ,@c_Storerkey = O.Storerkey    
      FROM ORDERS O (NOLOCK)
      WHERE O.Loadkey = @c_Loadkey
      ORDER BY O.Orderkey*/
      SELECT TOP 1 
          @c_Consigneekey = O.Consigneekey
         ,@c_Storerkey    = O.Storerkey   
      FROM LoadPlanDetail LPD (NOLOCK)   
      JOIN ORDERS O WITH (NOLOCK) ON O.Orderkey = LPD.Orderkey  
      WHERE LPD.Loadkey = @c_Loadkey  
      ORDER BY O.Orderkey
      --WL02 END
   END
   ELSE
   BEGIN
      SELECT 
          @c_Consigneekey = O.Consigneekey
         ,@c_Storerkey = O.Storerkey    
      FROM ORDERS O (NOLOCK)
      WHERE O.Orderkey = @c_Orderkey
   END
   
   --SELECT TOP 1 @c_Consigneekey = O.Consigneekey
   --      ,@c_Storerkey = O.Storerkey                               
   --FROM PICKHEADER PH (NOLOCK)                                           
   --JOIN ORDERS O (NOLOCK) ON PH.ExternOrderKey = O.loadkey
   --WHERE PH.Pickheaderkey = @c_PickslipNo
   --ORDER BY O.orderkey 
   --(Wan01) - END   
   
   SELECT @c_Consigneekey = RIGHT('00000000' + LTRIM(RTRIM(ISNULL(@c_consigneekey,''))), 8)
   SELECT @c_Keyname = 'LBI-' + RTRIM(@c_Storerkey)
                                     
   EXECUTE dbo.nspg_GetKeyMinMax
    @c_keyname,
    6,  --field length    
    1,  -- min
    999999, --max          
    @c_Label_SeqNo OUTPUT,
    @b_Success     OUTPUT,
    @n_err         OUTPUT,
    @c_errmsg      OUTPUT
    
   IF @b_Success <> 1
      SELECT @n_Continue = 3
      
   SET @c_Consigneekey = RIGHT('0000' + LTRIM(RTRIM(@c_Consigneekey)),4) --NJOW01
   
   --WL01 Start
   --SELECT @c_LabelNo = RTRIM(@c_Consigneekey) + CONVERT(NVARCHAR(6),GETDATE(),12) + RTRIM(LTRIM(ISNULL(@c_Label_SeqNo,'')))     
   SELECT @c_LabelNo = LEFT('LFSH' + RTRIM(@c_Consigneekey) + CONVERT(NVARCHAR(6),GETDATE(),12) + RTRIM(LTRIM(ISNULL(@c_Label_SeqNo,''))),20) --Limit 20 Chars
   --WL01 End   
 
   IF @n_Continue=3  -- Error Occured - Process And Return
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_GLBL05"
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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