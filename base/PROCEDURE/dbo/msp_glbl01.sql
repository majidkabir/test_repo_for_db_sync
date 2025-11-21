SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure: msp_GLBL01                                          */
/* Creation Date: 04-Jun-2024                                           */
/* Copyright: Maersk                                                    */
/* Written by: SHONG                                                    */
/*                                                                      */
/* Purpose: UWP-18747 - Levis US MPOC and Cartonization                 */
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
/* Date         Author  Ver.  Purposes                                  */
/* 04-Jun-2024  Shong   1.0   Creation                                  */
/* 31-Oct-2024  WLChooi 1.1   Cater for MPOC (WL01)                     */
/************************************************************************/
 CREATE   PROC [dbo].[msp_GLBL01] (
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
         , @c_RangeStart         NVARCHAR(60)   = ''
         , @c_RangeEnd           NVARCHAR(60)   = ''
         , @c_Storerkey          NVARCHAR(15)   = ''
         , @c_Consigneekey       NVARCHAR(15)   = ''
         , @c_CTNTrackNo         NVARCHAR(40)   = ''
         , @c_CompanyPrefix      NVARCHAR(40)   = ''
         , @c_LBLNoPrefix        NVARCHAR(10)   = ''
         , @n_LBLNoLength        INT            = 0
         , @n_CartonNo_Last      INT            = 0
         , @n_CartonNo_New       INT            = 0
         , @n_QtyAllocated       INT            = 0
         , @n_QtyPacked          INT            = 0
         , @c_Loadkey            NVARCHAR(10)   = ''
         , @b_GS1LabelFlag       BIT = 1

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
         , @n_CharIndex          INT = 0

   SET @n_StartTCnt        = @@TRANCOUNT
   SET @n_Continue         = 1
   SET @b_Success          = 0
   SET @n_Err              = 0
   SET @c_ErrMsg           = ''

   SET @c_Orderkey = ''
   SET @c_Storerkey= ''
   SELECT @c_Orderkey = P.Orderkey
         ,@c_Storerkey= P.Storerkey
   FROM dbo.PACKHEADER P WITH (NOLOCK)
   WHERE P.PickSlipNo = @c_PickSlipNo

   SET @n_QtyPacked = 0
   SELECT @n_QtyPacked = ISNULL(SUM(PD.Qty),0)
   FROM dbo.PACKDETAIL PD WITH (NOLOCK)
   WHERE PD.PickSlipNo = @c_PickSlipNo

   --WL01 S
   IF @c_Orderkey = '' 
   BEGIN
      --SET @c_LabelNo = 'ERROR-1001'
      --GOTO QUIT_SP

      SELECT @c_Consigneekey = MAX(O.ConsigneeKey)
      FROM PICKHEADER P (NOLOCK)
      JOIN WAVEDETAIL WD (NOLOCK) ON WD.Wavekey = P.Wavekey
      JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
      WHERE P.Pickheaderkey = @c_Pickslipno
   END
   ELSE
   BEGIN
      SELECT @c_Consigneekey = O.ConsigneeKey 
      FROM dbo.ORDERS O WITH (NOLOCK) 
      WHERE O.OrderKey = @c_Orderkey
   END

   --SELECT @c_Consigneekey = O.ConsigneeKey 
   --FROM dbo.ORDERS O WITH (NOLOCK) 
   --WHERE O.OrderKey = @c_Orderkey
   --WL01 E

   IF EXISTS(SELECT 1
             FROM dbo.CODELKUP CLK WITH (NOLOCK) 
             WHERE CLK.LISTNAME = 'GS1xLabel'
             AND CLK.Code = @c_Consigneekey)
   BEGIN
      SET @b_GS1LabelFlag = 0
      SET @n_LBLNoLength = 7
      SET @c_LBLNoPrefix = 'Y'
      SET @c_Keyname = 'LVSLabel'
   END 
   ELSE
   BEGIN
      SELECT @c_CompanyPrefix = ISNULL(SUSR5,'')
      FROM dbo.STORER WITH (NOLOCK) 
      WHERE StorerKey = @c_Storerkey

      SELECT @c_RangeStart = ISNULL(CLK.UDF01,''), 
             @c_RangeEnd   = ISNULL(CLK.UDF02,'') 
      FROM dbo.CODELKUP CLK WITH (NOLOCK) 
      WHERE CLK.LISTNAME = 'GS1Range'     

      SET @b_GS1LabelFlag = 1      
      SET @c_LBLNoPrefix = ''
      SET @n_LBLNoLength = LEN(@c_RangeStart) 
      SET @c_Keyname = 'GS1Label'
   END

   SET @c_Identifier = '00'
   SET @c_Packtype = '0'
   SET @c_LabelNo = ''

   EXECUTE nspg_GetKey
   @c_Keyname ,
   @n_LBLNoLength,
   @c_nCounter     Output ,
   @b_success      = @b_success output,
   @n_err          = @n_err output,
   @c_errmsg       = @c_errmsg output,
   @b_resultset    = 0,
   @n_batch        = 1

   IF @b_GS1LabelFlag = 0
   BEGIN
      SET @c_LabelNo = @c_LBLNoPrefix + RTRIM(@c_nCounter) 
   END
   ELSE
   BEGIN
      -- GS1 Label Number
      SET @c_LabelNo = @c_CompanyPrefix + RTRIM(@c_nCounter)

      IF ISNUMERIC(@c_LabelNo) <> 1
      BEGIN
         SET @c_LabelNo = 'ERROR-1002'
         GOTO QUIT_SP          
      END

      SET @n_Add = 0
      SET @n_Remain = 0
      SET @n_CheckDigit = 0

      WHILE @n_CharIndex <= LEN(RTRIM(@c_LabelNo))
      BEGIN
         IF @n_CharIndex % 2 = 1 -- Odd positions: multiply by 3
            SET @n_TotalOddCnt = @n_TotalOddCnt + ( CAST(SUBSTRING(@c_LabelNo, @n_CharIndex, 1) AS INT) * 3) 
         ELSE 
            SET @n_TotalEvenCnt = @n_TotalEvenCnt + ( CAST(SUBSTRING(@c_LabelNo, @n_CharIndex, 1) AS INT) * 1) 

         SET @n_CharIndex = @n_CharIndex + 1
      END -- End While
      
      SET @n_Add = @n_TotalOddCnt + @n_TotalEvenCnt
      SET @n_Remain = @n_Add % 10
      SET @n_CheckDigit = 10 - @n_Remain

      IF @n_CheckDigit = 10
         SET @n_CheckDigit = 0

      SET @c_LabelNo = ISNULL(RTRIM(@c_LabelNo), '') + CAST(@n_CheckDigit AS NVARCHAR( 1))
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "msp_GLBL01"
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