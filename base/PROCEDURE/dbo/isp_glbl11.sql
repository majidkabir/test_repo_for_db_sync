SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_GLBL11                                          */
/* Creation Date: 18-Sep-2017                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-2796 CN PVH UCC Label no                                */ 
/*                                                                      */
/* Input Parameters:  @c_PickSlipNo-Pickslipno, @n_CartonNo - CartonNo  */
/*                    Storerconfig: GenLabelNo_SP='isp_GLBL11'          */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage: Call from isp_GenLabelNo_Wrapper                              */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 20-Jan-2020  WLChooi  1.1  Performance Tuning (WL01)                 */
/* 25-May-2022  WLChooi  1.2  DevOps Combine Script                     */
/* 25-May-2022  WLChooi  1.2  WMS-19740 - Add new logic for CN (WL02)   */
/************************************************************************/

CREATE PROC [dbo].[isp_GLBL11] ( 
         @c_PickSlipNo   NVARCHAR(10) 
      ,  @n_CartonNo     INT
      ,  @c_LabelNo      NVARCHAR(20)   OUTPUT )
AS
BEGIN
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
      
   DECLARE @n_StartTCnt     INT
          ,@n_Continue      INT
          ,@b_Success       INT 
          ,@n_Err           INT  
          ,@c_ErrMsg        NVARCHAR(255)
          ,@c_Label_SeqNo   NVARCHAR(9)
          ,@c_Prefix        NVARCHAR(30)  
          ,@c_Country       NVARCHAR(20)   --WL02
          ,@c_OHUDF10       NVARCHAR(50)   --WL02
          ,@c_CLCode2       NVARCHAR(50)   --WL02
          ,@c_CLUDF03       NVARCHAR(50)   --WL02
          ,@c_Storerkey     NVARCHAR(15)   --WL02
          ,@c_Facility      NVARCHAR(5)    --WL02
          ,@c_Type          NVARCHAR(10)   --WL02
   
   DECLARE @n_CheckDigit    INT
          ,@n_TotalCnt      INT
          ,@n_TotalOddCnt   INT
          ,@n_TotalEvenCnt  INT
          ,@n_Add           INT
          ,@n_Remain        INT
          ,@n_OddCnt        INT
          ,@n_EvenCnt       INT
          ,@n_Odd           INT
          ,@n_Even          INT
   
   SET @n_StartTCnt         = @@TRANCOUNT
   SET @n_Continue          = 1
   SET @b_Success           = 0
   SET @n_Err               = 0
   SET @c_ErrMsg            = ''   
   SET @c_LabelNo           = ''

   --WL02 S
   SELECT @c_Country = N.NSQLValue
   FROM dbo.NSQLCONFIG N (NOLOCK)
   WHERE N.ConfigKey = 'Country'
   --WL02 E
	 
    SELECT TOP 1 @c_Prefix = O.RDD 
               , @c_OHUDF10 = O.UserDefine10   --WL02
               , @c_Storerkey = O.StorerKey    --WL02
               , @c_Facility = O.Facility      --WL02
               , @c_Type = O.[Type]            --WL02
	 FROM PICKHEADER PH (NOLOCK)
	 JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
	 WHERE PH.Pickheaderkey = @c_Pickslipno
	 
	 IF ISNULL(@c_Prefix,'') = ''
	 BEGIN
       SELECT TOP 1 @c_Prefix = O.RDD 
                  , @c_OHUDF10 = O.UserDefine10   --WL02
                  , @c_Storerkey = O.StorerKey    --WL02
                  , @c_Facility = O.Facility      --WL02
                  , @c_Type = O.[Type]            --WL02
       FROM PICKHEADER PH (NOLOCK)
       --JOIN ORDERS O (NOLOCK) ON PH.ExternOrderkey = O.Loadkey             --WL01
       JOIN LOADPLANDETAIL LPD (NOLOCK) ON PH.ExternOrderkey = LPD.Loadkey   --WL01
       JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey                   --WL01
       WHERE PH.Pickheaderkey = @c_Pickslipno	 	
       ORDER BY O.RDD DESC
	 END

   --WL02 S
   IF @c_Country = 'CN'
   BEGIN
      IF @c_Type = 'WTW'
      BEGIN
         EXECUTE nspg_GetKey
         'PACKNO', 
         18 ,
         @c_LabelNo  OUTPUT,
         @b_success  OUTPUT,
         @n_err      OUTPUT,
         @c_errmsg   OUTPUT

         IF @b_Success <> 1 
         BEGIN
            SELECT @n_Continue = 3         
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg ='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Failed to get LabelNo for Type: WTW (isp_GLBL11)' 
                             + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         END

         GOTO QUIT_SP
      END

      SELECT @c_CLCode2 = ISNULL(CL1.Code2,'')
      FROM CODELKUP CL1 (NOLOCK)
      WHERE CL1.LISTNAME = 'PVHBRAND'
      AND CL1.Storerkey = @c_Storerkey
      AND CL1.Long = @c_OHUDF10

      IF @c_CLCode2 <> 'DOM'
      BEGIN
         SELECT @c_CLUDF03 = ISNULL(CL.UDF03,'')
         FROM CODELKUP CL (NOLOCK)
         WHERE CL.LISTNAME = 'PVHECOMFAC'
         AND CL.Storerkey = @c_Storerkey
         AND CL.Short = @c_Facility

         SET @c_Prefix = @c_CLUDF03
      END
   END
   --WL02 E

   IF ISNULL(@c_Prefix,'') = ''
   BEGIN
      SELECT @n_Continue = 3         
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Empty Prefix(RDD) (isp_GLBL11)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
      GOTO QUIT_SP
   END
	 
   EXECUTE dbo.nspg_GetKey           
           'PVHLBLNO',                      
           9,                               
           @c_Label_SeqNo OUTPUT,           
           @b_Success     OUTPUT,           
           @n_err         OUTPUT,           
           @c_errmsg      OUTPUT            
                                   
   IF @b_Success <> 1                
   BEGIN
      SELECT @n_Continue = 3         
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Getkey(PVHLBLNO) (isp_GLBL11)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
      GOTO QUIT_SP
   END

   SET @c_labelno = LTRIM(RTRIM(ISNULL(@c_Prefix,''))) + LTRIM(RTRIM(ISNULL(@c_Label_SeqNo,'')))  
   
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
   SET @n_EvenCnt = 0
   SET @n_TotalEvenCnt = 0
   
	 WHILE @n_Even <= 20 
   BEGIN
		  SET @n_EvenCnt = CAST(SUBSTRING(@c_LabelNo, @n_Even, 1) AS INT)
		  SET @n_TotalEvenCnt = @n_TotalEvenCnt + @n_EvenCnt
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
   
	 SET @c_LabelNo = ISNULL(RTRIM(@c_LabelNo), '') + CAST(@n_CheckDigit AS NVARCHAR(1))	 	 	 
   
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_GLBL11"
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