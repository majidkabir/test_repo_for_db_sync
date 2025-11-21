SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispPKLotChk03                                      */
/* Creation Date: 27-Jan-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-16079 - RG - LEGO - EXCEED Packing                      */   
/*                                                                      */
/* Called By: Packing lottable -> isp_PackLottableCheck_Wrapper         */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */ 
/* 27-Jan-2021 Wan01    1.0   Created.                                  */    
/************************************************************************/

CREATE PROC [dbo].[ispPKLotChk03]   
      @c_PickslipNo    NVARCHAR(10)   
   ,  @c_Storerkey     NVARCHAR(15)
   ,  @c_Sku           NVARCHAR(20)
   ,  @c_LottableValue NVARCHAR(60)
   ,  @n_Cartonno      INT
   ,  @n_PackingQty    INT
   ,  @b_Success       INT           OUTPUT
   ,  @n_Err           INT           OUTPUT
   ,  @c_ErrMsg        NVARCHAR(250) OUTPUT
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_Continue           INT = 1
         , @n_StartTCnt          INT = @@TRANCOUNT
         
         , @c_Orderkey           NVARCHAR(10) = ''
         , @c_C_Country          NVARCHAR(30) = ''
         , @c_Country_ST         NVARCHAR(30) = ''      
         
   DECLARE @TChkLAValue       TABLE 
      (  LottableValue  NVARCHAR(60) NOT NULL DEFAULT('') )
                                                       
   SET @n_Err = 0
   SET @c_ErrMsg = ''
   SET @b_Success = 1
   
   SELECT @c_Orderkey = PH.Orderkey
   FROM PICKHEADER PH WITH (NOLOCK)
   WHERE PH.PickHeaderKey = @c_PickslipNo
   
   IF @c_Orderkey <> ''
   BEGIN
      SELECT @c_C_Country = ISNULL(OH.C_Country,'')
      FROM ORDERS OH WITH (NOLOCK) 
      WHERE OH.OrderKey = @c_Orderkey
   END
   
   SELECT @c_Country_ST = ISNULL(s.Country,'')
   FROM STORER AS s WITH (NOLOCK)
   WHERE s.Storerkey = @c_Storerkey

   IF @c_Country_ST <> '' AND @c_Country_ST <> @c_C_Country
   BEGIN
      IF ISNULL(@c_LottableValue,'') = ''
      BEGIN
         SET @n_continue = 3    
         SET @n_err = 61910-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
         SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Lottable is empty for Sku: ' + RTRIM(ISNULL(@c_Sku,'')) + '. (ispPKLotChk03)'          
         GOTO QUIT_SP
      END
   END 
   
   INSERT INTO @TChkLAValue
   (
         LottableValue -- this column value is auto-generated
   )
   VALUES
   (
         @c_LottableValue
   ) 
   
   INSERT INTO @TChkLAValue
   (
         LottableValue 
   )
   SELECT ISNULL(pd.LOTTABLEVALUE,'')
   FROM PackDetail AS pd WITH (NOLOCK)
   WHERE pd.PickSlipNo = @c_PickslipNo
   AND pd.CartonNo = @n_Cartonno
   AND pd.storerkey= @c_Storerkey
   AND pd.sku = @c_Sku
   
   IF EXISTS (SELECT 1
              FROM @TChkLAValue t
              HAVING COUNT(DISTINCT LottableValue) > 1
   )
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 67010
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Cannot have mix COO for same Sku. (ispPKLotChk03)'
      GOTO QUIT_SP
   END
   
   QUIT_SP:
   
   IF @n_Continue=3  -- Error Occured - Process AND Return
   BEGIN
      SET @b_Success = 0
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
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispPKLotChk03'    
      --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END  
END  

GO