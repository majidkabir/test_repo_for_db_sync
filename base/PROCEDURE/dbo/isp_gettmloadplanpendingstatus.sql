SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_GetTMLoadplanPendingStatus                     */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 04-Mar-2010  Shong    1.1  Fixed Summary Loadplan Cnt not tally with */
/*                            list view. (SHONG001)                     */
/* 10-Mar-2010  Vicky    1.1  HVCP should show # of Cartons (Vicky01)   */
/* 17-Mar-2010  ChewKP   1.1  Add in Loose QTY (ChewKP01)               */
/* 18-Mar-2010  ChewKP   1.1  Add in Loose QTY for VAS (ChewKP02)       */
/* 19-Mar-2010  Vicky    1.1  Loose QTY should show on VAS (Vicky02)    */
/* 06-May-2010  SHONG    1.1  Calling isp_GetPPKPltCase2 instead of     */
/*                            isp_GetPPKPltCase                         */
/* 02-Aug-2010  GTGOH    1.2  Fixed wrong calculation (GOH01)           */
/* 05-Mar-2012  Leong    1.3  SOS# 238091 - Sort by Pickup date         */
/*                                        - Set invisible in PB object  */
/*                                          when date = 2999-01-01      */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
/************************************************************************/

CREATE PROC [dbo].[isp_GetTMLoadplanPendingStatus]
   @c_Facility NVARCHAR(5),
   @c_Section  NVARCHAR(10),
   @c_AreaKey  NVARCHAR(10)
AS
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @c_LoadKey         NVARCHAR(10)
      , @c_ExternOrderKey  NVARCHAR(50)   --tlting_ext
      , @c_ConsigneeKey    NVARCHAR(15)
      , @c_ToAlsie         NVARCHAR(10)
      , @n_Cartons         INT
      , @n_HVCPCtns        INT
      , @n_ProcCtns        INT
      , @n_VASCtns         INT
      , @d_CancelDate      DATETIME
      , @d_PickUpDate      DATETIME
      , @c_LOC             NVARCHAR(10)
      , @c_ID              NVARCHAR(18)
      , @c_LaneType        NVARCHAR(10)
      , @n_ShipTo          INT
      , @n_CustOrder       INT      --GOH01
      , @c_StorerKey       NVARCHAR(15)
      , @n_LooseQty        INT   -- (ChewKP01)
      , @n_TotalLooseQTY   INT   -- (ChewKP01)
      , @n_VASTotLooseQTY  INT   -- (ChewKP02)


CREATE TABLE #PendingRelease (
     LoadKey         NVARCHAR(10)
   , StorerKey       NVARCHAR(15)
   , CancelDate      DATETIME NULL
   , TotCtns         INT NULL
   , PickUpDate      DATETIME NULL
   , ProcAreaCtn     INT NULL
   , HVCPAreaCtn     INT NULL
   , VASAreaCtn      INT NULL
   , TotLoose        INT NULL -- (ChewKP01)
   , VASTotLooseQTY  INT NULL  -- (ChewKP02)
   )

-- (SHONG001)
DECLARE CUR_CAL_PltCase  CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT L.LoadKey, P.StorerKey
   FROM PickDetail P WITH (NOLOCK)
   JOIN LOC WITH (NOLOCK) ON LOC.Loc = P.Loc
   -- JOIN PutawayZone FPZ WITH (NOLOCK)
   LEFT JOIN PutawayZone FPZ WITH (NOLOCK)  --GOH01
   ON FPZ.PutawayZone = LOC.PutawayZone
   -- JOIN AreaDetail FAD WITH (NOLOCK)
   LEFT JOIN AreaDetail FAD WITH (NOLOCK)   --GOH01
   ON FAD.PutawayZone = FPZ.PutawayZone
   JOIN LoadplanDetail LPD WITH (NOLOCK) ON LPD.OrderKey = P.OrderKey
   JOIN Loadplan L WITH (NOLOCK) ON L.Loadkey = LPD.Loadkey
   WHERE ISNULL(LOC.Facility,'') = CASE WHEN @c_Facility='ALL' THEN ISNULL(LOC.Facility,'')
                                   ELSE @c_Facility
                                   END
   AND ISNULL(LOC.SectionKey,'') = CASE WHEN @c_Section='ALL' THEN ISNULL(LOC.SectionKey,'')
                                   ELSE @c_Section
                                   END
   AND ISNULL(FAD.AreaKey,'') = CASE WHEN @c_AreaKey='ALL' THEN ISNULL(FAD.AreaKey,'')
                                ELSE @c_AreaKey
                                END
   AND L.Status IN ('1','2') AND L.ProcessFLag NOT IN ('Y')

   OPEN CUR_CAL_PltCase
   FETCH NEXT FROM CUR_CAL_PltCase INTO @c_LoadKey, @c_StorerKey

   WHILE @@FETCH_STATUS <> -1
   BEGIN
   --GOH01 Mask
   --    IF NOT EXISTS(
   --           SELECT 1
   --           FROM   #PendingRelease PR
   --           WHERE  PR.LoadKey = @c_LoadKey
   --       )
   --    BEGIN
      SELECT @d_CancelDate = MAX(O.DeliveryDate)
      FROM ORDERS O WITH (NOLOCK)
      JOIN LoadPlanDetail LPD WITH (NOLOCK) ON LPD.OrderKey = O.OrderKey
      WHERE  LPD.LoadKey = @c_LoadKey AND O.DeliveryDate IS NOT NULL
      AND O.StorerKey = @c_StorerKey   --GOH01

      SELECT TOP 1 @d_PickUpDate = CASE WHEN M.UserDefine07 IS NULL THEN LP.UserDefine07 END
      FROM LoadPlanDetail LPD WITH (NOLOCK)
      JOIN LoadPlan LP WITH (NOLOCK) ON LP.LoadKey = LPD.LoadKey
      JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = LPD.OrderKey
      LEFT OUTER JOIN MBOLDETAIL m WITH (NOLOCK) ON M.OrderKey = O.OrderKey
      LEFT OUTER JOIN MBOL WITH (NOLOCK) ON MBOL.MbolKey = M.MbolKey
      WHERE LPD.LoadKey = @c_LoadKey
      AND O.StorerKey = @c_StorerKey   --GOH01

      SET @n_HVCPCtns = 0
      SET @n_ProcCtns = 0
      SET @n_VASCtns = 0
      SET @n_TotalLooseQTY = 0 -- (ChewKP01)
      SET @n_VASTotLooseQTY = 0 -- (ChewKP02)

      DECLARE C_PickTask  CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT P.LOC, P.ID, COUNT(DISTINCT O.ConsigneeKey)
              , COUNT(DISTINCT O.ExternOrderKey)     --GOH01
         FROM  PickDetail P WITH (NOLOCK)
         JOIN LoadPlanDetail LPD WITH (NOLOCK) ON LPD.OrderKey = P.OrderKey
         JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = P.OrderKey
         JOIN LoadPlan LP WITH (NOLOCK) ON LP.LoadKey = LPD.LoadKey
         JOIN LOC FL WITH (NOLOCK) ON FL.Loc = P.Loc
         -- JOIN PutawayZone FPZ WITH (NOLOCK)
         LEFT JOIN PutawayZone FPZ WITH (NOLOCK)    --GOH01
            ON FPZ.PutawayZone = FL.PutawayZone
         -- JOIN AreaDetail FAD WITH (NOLOCK)
         LEFT JOIN AreaDetail FAD WITH (NOLOCK)     --GOH01
            ON FAD.PutawayZone = FPZ.PutawayZone
         WHERE LPD.LoadKey = @c_LoadKey AND P.STATUS < '9'
         AND ISNULL(FL.Facility,'') = CASE WHEN @c_Facility='ALL' THEN ISNULL(FL.Facility,'')
                                      ELSE @c_Facility
                                      END
         AND ISNULL(FL.SectionKey,'') = CASE WHEN @c_Section='ALL' THEN ISNULL(FL.SectionKey,'')
                                        ELSE @c_Section
                                        END
         AND ISNULL(FAD.AreaKey,'') = CASE WHEN @c_AreaKey='ALL' THEN ISNULL(FAD.AreaKey,'')
                                      ELSE @c_AreaKey
                                      END
         AND P.StorerKey = @c_StorerKey   --GOH01
         GROUP BY P.LOC, P.ID, LP.Priority

      OPEN C_PickTask
      FETCH NEXT FROM C_PickTask INTO @c_Loc, @c_ID, @n_ShipTo, @n_CustOrder --GOH01

      WHILE (@@FETCH_STATUS <> -1)
      BEGIN

         -- Is Loadplan.UserDefine08 = 'Y' (Work Order)
         -- Then go to VAS Location
         IF EXISTS( SELECT 1 FROM Loadplan WITH (NOLOCK)
                    WHERE  LoadKey = @c_LoadKey AND ISNUMERIC(UserDefine10) = 1 )
         BEGIN
            SET @c_LaneType = 'VAS'
         END
         ELSE
         -- IF @n_ShipTo=1  -- 1 Ship to then go to processing area
         IF @n_ShipTo = 1 AND @n_CustOrder = 1   -- GOH01
         BEGIN
            SET @c_LaneType = 'Proc'
         END
         ELSE
         BEGIN
            SET @c_LaneType = 'HVCP'
         END

         EXEC isp_GetPPKPltCase2
              @c_loadkey = @c_LoadKey
            , @n_totalcarton = @n_Cartons OUTPUT
            , @n_totalloose = @n_LooseQty OUTPUT   -- (ChewKP01)
            , @c_LOC = @c_LOC
            , @c_ID = @c_ID
            , @c_GetTotPallet = 'N'

         SET @n_TotalLooseQTY = @n_TotalLooseQTY + @n_LooseQty -- (ChewKP01)

         IF @c_LaneType='VAS'
         BEGIN
            SET @n_VASCtns = @n_VASCtns+@n_Cartons
            SET @n_VASTotLooseQTY  = @n_VASTotLooseQTY + @n_LooseQty  -- (ChewKP02)
         END
         ELSE
         IF @c_LaneType='Proc'
         BEGIN
            SET @n_ProcCtns = @n_ProcCtns+@n_Cartons
         END
         ELSE
         IF @c_LaneType='HVCP'
         BEGIN
            SET @n_HVCPCtns = @n_HVCPCtns+@n_Cartons --0  -- (Vicky01)
         END

         FETCH NEXT FROM C_PickTask INTO @c_Loc, @c_ID, @n_ShipTo, @n_CustOrder  --GOH01
      END -- WHILE 1=1
      CLOSE C_PickTask
      DEALLOCATE C_PickTask

      --GOH01 Start
      IF NOT EXISTS( SELECT 1 FROM #PendingRelease PR
                     WHERE PR.LoadKey = @c_LoadKey
                     AND PR.StorerKey = @c_StorerKey)
      BEGIN
         INSERT INTO #PendingRelease (
                 LoadKey, StorerKey, CancelDate, TotCtns, PickUpDate, ProcAreaCtn
               , HVCPAreaCtn, VASAreaCtn, TotLoose, VASTotLooseQTY -- (ChewKP01) -- (ChewKP02)
               )
         VALUES (
                 @c_LoadKey, @c_StorerKey, @d_CancelDate, @n_HVCPCtns + @n_ProcCtns + @n_VASCtns
               , @d_PickUpDate, @n_ProcCtns, @n_HVCPCtns, @n_VASCtns, @n_TotalLooseQTY, @n_VASTotLooseQTY  -- (ChewKP01) -- (ChewKP01)
               )
      END
      ELSE
      --GOH01 End
      BEGIN
         UPDATE #PendingRelease
         SET  TotCtns = TotCtns + @n_HVCPCtns + @n_ProcCtns + @n_VASCtns
            , ProcAreaCtn = ProcAreaCtn + @n_ProcCtns
            , HVCPAreaCtn = HVCPAreaCtn + @n_HVCPCtns
            , VASAreaCtn = VASAreaCtn + @n_HVCPCtns
         WHERE LoadKey = @c_LoadKey
         AND StorerKey = @c_StorerKey   --GOH01
      END

      FETCH NEXT FROM CUR_CAL_PltCase INTO @c_LoadKey, @c_StorerKey
   END
   CLOSE CUR_CAL_PltCase
   DEALLOCATE CUR_CAL_PltCase

--SELECT * FROM #PendingRelease  -- (Vicky02)
-- (Vicky02) - Start
SELECT LoadKey, StorerKey, ISNULL(CancelDate,'2999-01-01') AS CancelDate, TotCtns, ISNULL(PickUpDate,'2999-01-01') AS PickUpDate, ProcAreaCtn, HVCPAreaCtn
     , CASE WHEN VASAreaCtn = 0 AND VASTotLooseQTY > 0 THEN VASTotLooseQTY
            WHEN VASAreaCtn > 0 THEN VASAreaCtn
       ELSE 0 END AS VASAreaCtn
     , TotLoose
     , VASTotLooseQTY
FROM #PendingRelease
ORDER BY ISNULL(PickUpDate,'2999-01-01') -- SOS# 238091
-- (Vicky02) - End

GO