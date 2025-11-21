SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_Carton_SerialCard_Label_01                     */
/* Creation Date: 18-Sep-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-23669 - [CN] GM serial card label printing new          */
/*                                                                      */
/* Called By: report dw = r_dw_carton_serialcard_label_01               */
/*                                                                      */
/* GitHub Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver.  Purposes                                 */
/* 18-Sep-2023  WLChooi  1.0   DevOps Combine Script                    */
/************************************************************************/

CREATE   PROC [dbo].[isp_Carton_SerialCard_Label_01]
(@c_Pickslipno NVARCHAR(10), @c_CartonNoStart NVARCHAR(10), @c_CartonNoEnd NVARCHAR(10) )
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET ANSI_DEFAULTS OFF

   DECLARE @n_Continue INT = 1
         , @c_CartonNoStartTemp  NVARCHAR(10) = ''
         , @c_CartonNoEndTemp    NVARCHAR(10) = ''

   IF @c_CartonNoStart > @c_CartonNoEnd
   BEGIN
      SET @c_CartonNoStartTemp = @c_CartonNoStart
      SET @c_CartonNoEndTemp = @c_CartonNoEnd

      SET @c_CartonNoStart = @c_CartonNoEndTemp
      SET @c_CartonNoEnd = @c_CartonNoStartTemp
   END

   DECLARE @T_OD TABLE ( DESCR NVARCHAR(250), Notes NVARCHAR(4000), Salesman NVARCHAR(50), TodayDate NVARCHAR(20) )

   INSERT INTO @T_OD (DESCR, Notes, Salesman, TodayDate)
   SELECT DISTINCT
          DESCR = ISNULL(S.DESCR,'')
        , Notes = ISNULL(OD.Notes,'')
        , Salesman = ISNULL(OH.Salesman,'')
        , TodayDate = UPPER(CONVERT(NVARCHAR(11), GETDATE(), 113))
   FROM PACKDETAIL PD (NOLOCK)
   JOIN PACKHEADER PH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
   JOIN ORDERS OH (NOLOCK) ON OH.Orderkey = PH.Orderkey
   JOIN ORDERDETAIL OD (NOLOCK) ON OH.Orderkey = OD.Orderkey
   JOIN SKU S (NOLOCK) ON S.Storerkey = OD.Storerkey
	                   AND S.SKU = OD.SKU
   WHERE PD.Pickslipno = @c_Pickslipno
   AND PD.CartonNo BETWEEN CAST(@c_CartonNoStart AS INT) AND CAST(@c_CartonNoEnd AS INT)
   AND OH.[Status] = '5'
   AND OH.DocType = 'E'
   AND S.SUSR1 = N'商品'

   SELECT T.DESCR, S.[Value] AS Serial, T.Salesman, T.TodayDate 
   FROM @T_OD T
   CROSS APPLY STRING_SPLIT(T.Notes, ',') S
   ORDER BY T.DESCR
END

GO