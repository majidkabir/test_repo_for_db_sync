SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RPT_LP_POPUPPLIST_007_1                        */
/* Creation Date:03-MAY-2023                                            */
/* Copyright:LFL                                                        */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-22467-RG migrate pickslip report to logi                */
/*                                                                      */
/* Called By: RPT_LP_POPUPPLIST_007_2                                   */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                          7           */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 03-MAY-2023  CSCHONG  1.0  DevOps Combine Script                     */
/************************************************************************/
CREATE   PROC [dbo].[isp_RPT_LP_POPUPPLIST_007_1]
(
   @c_LoadKey       NVARCHAR(10)
 , @c_PreGenRptData NVARCHAR(10)=''
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SELECT DISTINCT ORDERS.ExternOrderKey,   
         ORDERS.C_Company,   
         ORDERS.Status,   
         ORDERS.LabelPrice,
         ORDERS.Route,SUBSTRING(ORDERS.notes,0,3)  AS specialhandling
    FROM LoadPlanDetail WITH (NOLOCK)
    JOIN ORDERS WITH (NOLOCK) ON LoadPlanDetail.LoadKey = ORDERS.LoadKey
    JOIN ORDERDETAIL WITH (NOLOCK) ON ORDERS.OrderKey = ORDERDETAIL.OrderKey
   WHERE ( LoadPlanDetail.LoadKey = @c_LoadKey )
END

GO