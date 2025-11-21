SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_GLBL23                                          */
/* Creation Date: 07-SEP-2020                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-15102 - CN Natural Beauty generate tracking no          */  
/*                                                                      */
/* Input Parameters:  @c_PickSlipNo-Pickslipno, @n_CartonNo - CartonNo  */
/*                    storerconfig: GenLabelNo_SP                       */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage: Call from isp_GenLabelNo_Wrapper                              */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver.  Purposes                                  */
/* 2021-04-12  Wan02    1.1   WMS-16026 - PB-Standardize TrackingNo     */
/************************************************************************/
CREATE PROC [dbo].[isp_GLBL23] ( 
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
         
   DECLARE @c_Orderkey           NVARCHAR(10)   = ''
         , @c_ShipperKey         NVARCHAR(15)   = ''
         , @c_Storerkey          NVARCHAR(15)   = ''
         , @c_CTNTrackNo         NVARCHAR(40)   = ''
         , @n_CartonNo_Last      INT            = 0      
         , @n_CartonNo_New       INT            = 0      
         , @n_QtyAllocated       INT            = 0      
         , @n_QtyPacked          INT            = 0      
         , @c_Loadkey            NVARCHAR(10)   = ''     
  
   DECLARE @c_Identifier         NVARCHAR(2)    = ''  
         , @c_Packtype           NVARCHAR(1)    = ''  
         , @c_VAT                NVARCHAR(18)   = ''  
         , @c_nCounter           NVARCHAR(25)   = ''  
         , @c_Keyname            NVARCHAR(30)   = ''  
         , @c_PackNo_Long        NVARCHAR(250)  = ''  
         , @n_CheckDigit         INT = 0    
         , @n_TotalCnt           INT = 0    
         , @n_TotalOddCnt        INT = 0    
         , @n_TotalEvenCnt       INT = 0    
         , @n_Add                INT = 0    
         , @n_Divide             INT = 0    
         , @n_Remain             INT = 0    
         , @n_OddCnt             INT = 0    
         , @n_EvenCntt           INT = 0    
         , @n_Odd                INT = 0    
         , @n_Even               INT = 0   
          
   SET @n_StartTCnt        = @@TRANCOUNT
   SET @n_Continue         = 1
   SET @b_Success          = 0
   SET @n_Err              = 0
   SET @c_ErrMsg           = ''
   
   SET @c_Orderkey = ''
   SET @c_Storerkey= ''  
   SELECT @c_Orderkey = P.Orderkey  
         ,@c_Storerkey= P.Storerkey
         ,@c_Loadkey  = P.Loadkey  
   FROM PACKHEADER P WITH (NOLOCK)
   WHERE P.PickSlipNo = @c_PickSlipNo

   SET @n_QtyPacked = 0
   SELECT @n_QtyPacked = ISNULL(SUM(PD.Qty),0)
   FROM PACKDETAIL PD WITH (NOLOCK)
   WHERE PD.PickSlipNo = @c_PickSlipNo
         
   SET @c_ShipperKey = ''
   
   IF @c_Orderkey <> ''
   BEGIN
      SELECT @c_ShipperKey = O.ShipperKey
            ,@c_CTNTrackNo = CASE WHEN ISNULL(RTRIM(O.TrackingNo),'') <> '' THEN O.TrackingNo ELSE ISNULL(RTRIM(O.UserDefine04),'') END   --Wan02
      FROM ORDERS O WITH (NOLOCK)
      WHERE O.Orderkey = @c_Orderkey

      SET @n_QtyAllocated = 0
      SELECT @n_QtyAllocated = ISNULL(SUM(PD.Qty),0)
      FROM PICKDETAIL PD WITH (NOLOCK)
      WHERE PD.Orderkey = @c_Orderkey
   END
   ELSE
   BEGIN
      SET @n_QtyAllocated = 0
      SELECT @n_QtyAllocated = ISNULL(SUM(PD.Qty),0)
      FROM ORDERS OH WITH (NOLOCK)
      JOIN PICKDETAIL PD WITH (NOLOCK) ON OH.Orderkey = PD.Orderkey
      WHERE OH.Loadkey = @c_Loadkey
   END

   IF @n_QtyAllocated = @n_QtyPacked -- Fully Packed
   BEGIN
      SET @c_LabelNo = 'ERROR'
      GOTO QUIT_SP  
   END

   SET @c_LabelNo = ''
   IF @c_ShipperKey IN (SELECT DISTINCT Short FROM CODELKUP(NOLOCK) WHERE Listname = 'ASGNTNO'  AND Storerkey = @c_Storerkey)
   BEGIN 
      --IF EXISTS ( SELECT 1 
      --            FROM PACKHEADER PH WITH (NOLOCK)
      --            WHERE PH.PickSlipNo = @c_PickSlipNo
      --            AND TaskBatchNo = ''
      --          )
      --BEGIN
         SET @n_CartonNo_Last = 0                           
         SELECT TOP 1 @n_CartonNo_Last = PD.CartonNo        
         FROM PACKDETAIL PD WITH (NOLOCK)
         WHERE PD.PickSlipNo = @c_PickSlipNo
         ORDER BY PD.CartonNo DESC

         SET @n_CartonNo_New = @n_CartonNo_Last + 1         

         IF @n_CartonNo_New <> 1  --- If First Carton, Use Tracking from ORDERS.UserDefine04
         BEGIN
            SET @c_CTNTrackNo = ''

            IF @n_CartonNo_Last <> @n_CartonNo
            BEGIN
               SET @c_LabelNo = 'ERROR'
               GOTO QUIT_SP  
            END
     
            EXEC ispAsgnTNo2        
              @c_OrderKey    = @c_OrderKey           
            , @c_LoadKey     = ''        
            , @b_Success     = @b_Success    OUTPUT              
            , @n_Err         = @n_Err        OUTPUT              
            , @c_ErrMsg      = @c_ErrMsg     OUTPUT              
            , @b_ChildFlag   = 1        
            , @c_TrackingNo  = @c_CTNTrackNo OUTPUT         
        
            IF ISNULL(RTRIM(@c_CTNTrackNo),'') = ''        
            BEGIN      
               SET @c_CTNTrackNo = 'ERROR'            --(Wan02)  
               SET @n_continue = 3        
               SET @n_err = 60010          
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Get Empty Tracking #. (isp_GLBL23)'         
               GOTO QUIT_SP        
            END 
         END
         SET @c_LabelNo = @c_CTNTrackNo 
   END
   ELSE  
   BEGIN  
      IF EXISTS ( SELECT 1 FROM StorerConfig WITH (NOLOCK)    
                  WHERE StorerKey = @c_StorerKey    
                  AND ConfigKey = 'GenUCCLabelNoConfig'    
                  AND SValue = '1')    
      BEGIN    
         SET @c_Identifier = '00'    
         SET @c_Packtype = '0'      
         SET @c_LabelNo = ''    
    
         SELECT @c_VAT = ISNULL(Vat,'')    
         FROM Storer WITH (NOLOCK)    
         WHERE Storerkey = @c_Storerkey    
          
         IF ISNULL(@c_VAT,'') = ''    
            SET @c_VAT = '000000000'    
    
         IF LEN(@c_VAT) <> 9     
            SET @c_VAT = RIGHT('000000000' + RTRIM(LTRIM(@c_VAT)), 9)    
    
         --(Wan01) - Fixed if not numeric    
         IF ISNUMERIC(@c_VAT) = 0     
         BEGIN    
            SET @n_Continue = 3    
            SET @n_Err = 60000    
            SET @c_errmsg = 'NSQL ' + CONVERT(NCHAR(5),@n_Err) + ': Vat is not a numeric value. (isp_GLBL23)'    
            GOTO QUIT_SP    
         END     
         --(Wan01) - Fixed if not numeric    
    
         SELECT @c_PackNo_Long = Long     
         FROM  CODELKUP (NOLOCK)    
         WHERE ListName = 'PACKNO'    
         AND Code = @c_Storerkey    
         
         IF ISNULL(@c_PackNo_Long,'') = ''    
            SET @c_Keyname = 'TBLPackNo'    
         ELSE    
            SET @c_Keyname = 'PackNo' + LTRIM(RTRIM(@c_PackNo_Long))    
              
         EXECUTE nspg_getkey    
         @c_Keyname ,    
         7,    
         @c_nCounter     Output ,    
         @b_success      = @b_success output,    
         @n_err          = @n_err output,    
         @c_errmsg       = @c_errmsg output,    
         @b_resultset    = 0,    
         @n_batch        = 1    
             
         SET @c_LabelNo = @c_Identifier + @c_Packtype + RTRIM(@c_VAT) + RTRIM(@c_nCounter) --+ @n_CheckDigit    
    
         SET @n_Odd = 1    
         SET @n_OddCnt = 0    
         SET @n_TotalOddCnt = 0    
         SET @n_TotalCnt = 0    
    
         WHILE @n_Odd <= 20     
         BEGIN    
            SET @n_OddCnt = CAST(SUBSTRING(@c_LabelNo, @n_Odd, 1) AS INT)    
            SET @n_TotalOddCnt = @n_TotalOddCnt + @n_OddCnt    
            SET @n_Odd = @n_Odd + 2    
         END    
    
         SET @n_TotalCnt = (@n_TotalOddCnt * 3)     
       
         SET @n_Even = 2    
         SET @n_EvenCntt = 0    
         SET @n_TotalEvenCnt = 0    
    
         WHILE @n_Even <= 20     
         BEGIN    
            SET @n_EvenCntt = CAST(SUBSTRING(@c_LabelNo, @n_Even, 1) AS INT)    
            SET @n_TotalEvenCnt = @n_TotalEvenCnt + @n_EvenCntt    
            SET @n_Even = @n_Even + 2    
         END    
    
         SET @n_Add = 0    
         SET @n_Remain = 0    
         SET @n_CheckDigit = 0    
    
         SET @n_Add = @n_TotalCnt + @n_TotalEvenCnt    
         SET @n_Remain = @n_Add % 10    
         SET @n_CheckDigit = 10 - @n_Remain    
    
         IF @n_CheckDigit = 10     
            SET @n_CheckDigit = 0    
    
         SET @c_LabelNo = ISNULL(RTRIM(@c_LabelNo), '') + CAST(@n_CheckDigit AS NVARCHAR( 1))    
      END   -- GenUCCLabelNoConfig    
      ELSE    
      BEGIN    
         EXECUTE nspg_GetKey    
            'PACKNO',     
            10 ,    
            @c_LabelNo  OUTPUT,    
            @b_success  OUTPUT,    
            @n_err      OUTPUT,    
            @c_errmsg   OUTPUT    
      END  
   END  
   QUIT_SP:

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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_GLBL23"
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