SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* S Proc: isp_LoadOrderSummary                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:                                                             */
/* Input Parameters: Storer Key                                         */
/*                                                                      */
/* Output Parameters: None                                              */
/*                                                                      */
/* Return Status: None                                                  */
/*                                                                      */
/* Usage: SOS#301734 - New Order Selection Summary Report               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: r_dw_load_order_summary                                   */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 09-07-2015   CSCHONG       SOS342280 (CS01)                          */
/* 11-07-2017   CSCHONG       WMS-2362- add new field (CS02)            */
/* 18-07-2018   CSCHONG       Performance tunning (CS03)                */
/* 13-09-2018   FayLiuHY      Add new column OrderNo (FayLiu01).        */
/************************************************************************/

CREATE PROC [dbo].[isp_LoadOrderSummary]
     @c_LoadKey     NVARCHAR(10)
   , @c_OrderCount  NVARCHAR(5)
   , @c_PickZones   NVARCHAR(4000) -- ZoneA,ZoneB,ZoneC,ZoneD,ZoneE (Comma delimited)
   , @c_Mode        NVARCHAR(1) = '0' -- 0 = Normal, 1 = Only batch order with total qty > 1 and with single pickzone, 2 = Only batch order with tota qty > 1 and with multi pickzone
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success      INT
         , @n_Err          INT
         , @n_Continue     INT
         , @n_StartTCnt    INT
         , @c_ErrMsg       NVARCHAR(250)

         , @n_cnt          INT
         , @n_OrderCount   INT

   SET @b_Success   = 1
   SET @n_Err       = 0
   SET @n_Continue  = 1
   SET @n_StartTCnt = @@TRANCOUNT
   SET @c_ErrMsg    = ''

   SET @n_OrderCount = CONVERT (INT, @c_OrderCount)

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   --SELECT @c_showField = CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END
   --FROM Codelkup CLR (NOLOCK)
   --WHERE CLR.Storerkey = @c_Storerkey
   --AND CLR.Code = 'SHOWFIELD'
   --AND CLR.Listname = 'REPORTCFG'
   --AND CLR.Long = 'r_dw_despatch_ticket_nikecn7' AND ISNULL(CLR.Short,'') <> 'N'

   EXEC ispOrderBatching
        @c_LoadKey     = @c_LoadKey
      , @n_OrderCount  = @n_OrderCount
      , @c_PickZones   = @c_PickZones -- ZoneA,ZoneB,ZoneC,ZoneD,ZoneE (Comma delimited)
      , @c_Mode        = @c_Mode      -- 0 = Normal, 1 = Only batch order with total qty > 1 and with single pickzone, 2 = Only batch order with tota qty > 1 and with multi pickzone
      , @b_Success     = @b_Success  OUTPUT
      , @n_Err         = @n_Err      OUTPUT
      , @c_ErrMsg      = @c_ErrMsg   OUTPUT

   IF @n_Err <> 0
   BEGIN
      SET @b_Success = 0
   END


   SELECT DISTINCT
          LPD.Loadkey
         ,OH.Orderkey
         ,ISNULL(RTRIM(OH.ExternOrderkey),'')
         ,ISNULL(RTRIM(LOC.PickZone),'')
         ,ISNULL(RTRIM(PD.Notes),'')
         ,@c_Mode
         ,ISNULL(RTRIM(PD.Pickslipno),'') AS Pickslipno --CS01
         ,DENSE_RANK() OVER (PARTITION by PD.Notes ORDER BY OH.OrderKey ) AS OrderNo -- FayLiu01
   FROM LOADPLANDETAIL LPD WITH (NOLOCK)
   JOIN ORDERS         OH  WITH (NOLOCK) ON (LPD.Orderkey = OH.Orderkey)
   JOIN PICKDETAIL     PD  WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)
   JOIN LOC            LOC WITH (NOLOCK) ON (PD.Loc = LOC.Loc)
   LEFT JOIN CODELKUP  CL  WITH (NOLOCK) ON CL.listname = 'EPLATFORM' AND CL.storerkey = OH.Storerkey  --CS03
                          AND (CL.Description = OH.UserDefine03)
   WHERE LPD.Loadkey = @c_Loadkey
   AND PD.Notes IS NOT NULL
   AND RTRIM(PD.Notes) <> ''
   AND PD.Notes Like '%' + @c_Mode
   AND   1 = @b_Success
   /*CS01 Start*/
   AND 1 = CASE
       WHEN ISNULL(CL.short,'') = '1' AND (OH.status='1') THEN '0'
     ELSE '1'
   END
   /*CS01 End*/
   ORDER BY ISNULL(RTRIM(LOC.PickZone),'')
          ,  ISNULL(RTRIM(PD.Notes),'')

   QUIT:
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END

GO