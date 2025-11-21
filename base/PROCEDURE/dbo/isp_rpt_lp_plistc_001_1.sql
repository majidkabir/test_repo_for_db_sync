SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Stored Procedure: isp_RPT_LP_PLISTC_001_1                               */
/* Creation Date: 20-JAN-2022                                              */
/* Copyright: LFL                                                          */
/* Written by: Harshitha                                                   */
/*                                                                         */
/* Purpose: WMS-18807                                                      */
/*                                                                         */
/* Called By: RPT_LP_PLISTC_001                                            */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 1.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author      Ver. Purposes                                  */
/* 24-Jan-2022  WLChooi     1.0  DevOps Combine Script                     */
/***************************************************************************/

CREATE PROC [dbo].[isp_RPT_LP_PLISTC_001_1]
      @c_LoadKey        NVARCHAR(10)
    , @c_PreGenRptData  NVARCHAR(10)
 AS
 BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SELECT DISTINCT ORDERS.ExternOrderKey,
                   ORDERS.C_Company,
                   ORDERS.Status,
                   ORDERS.LabelPrice
   FROM LOADPLANDETAIL (NOLOCK)
   JOIN ORDERDETAIL (NOLOCK) ON LoadPlanDetail.LoadKey = ORDERDETAIL.LoadKey
   JOIN ORDERS (NOLOCK) ON ORDERS.OrderKey = ORDERDETAIL.OrderKey
   WHERE LoadPlanDetail.LoadKey = @c_LoadKey

END -- Procedure

GO