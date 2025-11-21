SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RPT_RP_PICKSLIP_LABEL                          */
/* Creation Date: 16-Aug-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-23415 - [TW]PickSlipLabel_LogiReport_NEW                */
/*                                                                      */
/* Called By: RPT_RP_PICKSLIP_LABEL                                     */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 16-Aug-2023  WLChooi  1.0  DevOps Combine Script                     */
/************************************************************************/

CREATE   PROC [dbo].[isp_RPT_RP_PICKSLIP_LABEL]
   @c_LoadKey        NVARCHAR(10)
 , @c_PickSlipNo     NVARCHAR(10)
 , @c_Orderkey_Start NVARCHAR(10)
 , @c_Orderkey_End   NVARCHAR(10)
 , @n_Cartons        INT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Cnt     INT
         , @n_RowCnt  INT
         , @c_LabelNo NVARCHAR(15)

   SET @n_Cnt = 1
   SET @n_RowCnt = 0
   SET @c_LabelNo = N''

   CREATE TABLE ##PickSlipLabel
   (
      LabelNo NVARCHAR(15) NOT NULL DEFAULT ('')
   )

   IF RTRIM(@c_Orderkey_Start) = '' AND RTRIM(@c_Orderkey_End) <> ''
      SET @c_Orderkey_End = ''

   IF RTRIM(@c_Orderkey_Start) <> '' AND RTRIM(@c_Orderkey_End) = ''
      SET @c_Orderkey_End = @c_Orderkey_Start

   IF  RTRIM(@c_LoadKey) = ''
   AND RTRIM(@c_PickSlipNo) = ''
   AND RTRIM(@c_Orderkey_Start) = ''
   AND RTRIM(@c_Orderkey_End) = ''
      GOTO QUIT

   IF @n_Cartons = 0
      GOTO QUIT

   DECLARE C_PickSlip CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PICKHEADER.PickHeaderKey
   FROM PICKHEADER WITH (NOLOCK)
   JOIN ORDERS WITH (NOLOCK) ON (PICKHEADER.OrderKey = ORDERS.OrderKey)
   JOIN LoadPlanDetail WITH (NOLOCK) ON (LoadPlanDetail.OrderKey = ORDERS.OrderKey)
   WHERE PICKHEADER.PickHeaderKey = CASE WHEN ISNULL(RTRIM(@c_PickSlipNo), '') = '' THEN PICKHEADER.PickHeaderKey
                                         ELSE @c_PickSlipNo END
   AND   ORDERS.OrderKey BETWEEN CASE WHEN ISNULL(RTRIM(@c_Orderkey_Start), '') = '' THEN ORDERS.OrderKey
                                      ELSE @c_Orderkey_Start END AND CASE WHEN ISNULL(RTRIM(@c_Orderkey_End), '') = '' THEN
                                                                             ORDERS.OrderKey
                                                                          ELSE @c_Orderkey_End END
   AND   LoadPlanDetail.LoadKey = CASE WHEN ISNULL(RTRIM(@c_LoadKey), '') = '' THEN LoadPlanDetail.LoadKey
                                       ELSE @c_LoadKey END
   ORDER BY PICKHEADER.PickHeaderKey

   OPEN C_PickSlip

   FETCH NEXT FROM C_PickSlip
   INTO @c_PickSlipNo
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @n_Cnt = 1
      WHILE @n_Cnt <= @n_Cartons
      BEGIN
         SET @c_LabelNo = @c_PickSlipNo + CONVERT(NVARCHAR(1000), @n_Cnt)

         INSERT INTO ##PickSlipLabel (LabelNo)
         VALUES (@c_LabelNo)

         SET @n_Cnt = @n_Cnt + 1
      END
      FETCH NEXT FROM C_PickSlip
      INTO @c_PickSlipNo
   END
   CLOSE C_PickSlip
   DEALLOCATE C_PickSlip

   QUIT:
   SELECT LabelNo
   FROM ##PickSlipLabel

   IF OBJECT_ID('tempdb..##PickSlipLabel') IS NOT NULL
      DROP TABLE ##PickSlipLabel

END

GO