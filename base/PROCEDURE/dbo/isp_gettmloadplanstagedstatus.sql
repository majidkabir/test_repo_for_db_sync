SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_GetTMLoadplanStagedStatus                      */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.4                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* UPDates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 12-Mar-2010  Shong    1.0  Only show Loadplan's DropID in Staging    */
/* 17-Mar-2010  ChewKP   1.0  Add in Loose QTY (ChewKP01)               */
/* 05-May-2010  SHONG    1.1  Calling isp_GetPPKPltCase2                */
/* 13-May-2010  SHONG    1.2  Only Calculate Staged Carton Count with   */
/*                            Order.Status < '9'                        */
/* 27-May-2010  Vicky    1.3  Should also look at Orders with Status = 9*/
/*                            when calculating CtnInStage (Vicky01)     */
/* 05-Mar-2012  Leong    1.4  SOS# 238091 - Sort by Pickup date         */
/*                                        - Set invisible in PB object  */
/*                                          when date = 2999-01-01      */
/************************************************************************/

CREATE PROC [dbo].[isp_GetTMLoadplanStagedStatus]
   @c_Facility NVARCHAR(5),
   @c_Section  NVARCHAR(10),
   @c_AreaKey  NVARCHAR(10)
AS
SET NOCOUNT ON

DECLARE @c_LoadKey         NVARCHAR(10)
      , @c_ExternOrderKey  NVARCHAR(20)
      , @c_ConsigneeKey    NVARCHAR(15)
      , @c_ToAlsie         NVARCHAR(10)
      , @n_Cartons         INT
      , @n_TotalCtns       INT
      , @n_CtnInStage      INT
      , @n_VASCtns         INT
      , @d_CancelDate      DATETIME
      , @d_PickUpDate      DATETIME
      , @c_LOC             NVARCHAR(10)
      , @c_ID              NVARCHAR(18)
      , @c_LaneType        NVARCHAR(10)
      , @n_ShipTo          INT
      , @c_StorerKey       NVARCHAR(15)
      , @n_LooseQty        INT   -- (ChewKP01)
      , @n_TotalLooseQTY   INT   -- (ChewKP01)

CREATE TABLE #PendingRelease (
     LoadKey      NVARCHAR(10)
   , StorerKey    NVARCHAR(15)
   , CancelDate   DATETIME NULL
   , TotCtns      INT NULL
   , CtnInStage   INT DEFAULT 0
   , PercentComp  INT DEFAULT 0
   , PickUpDate   DATETIME NULL
   , TotLoose     INT NULL -- (ChewKP01)
   )

DECLARE CUR_CAL_PltCase  CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT LP.LoadKey, O.StorerKey
   FROM   Loadplan LP WITH (NOLOCK)
   JOIN DropID DI WITH (NOLOCK) ON  DI.Loadkey = LP.Loadkey
   JOIN LOC WITH (NOLOCK) ON  LOC.Loc = DI.DropLoc
   JOIN PutawayZone FPZ WITH (NOLOCK) ON  FPZ.PutawayZone = LOC.PutawayZone
   JOIN AreaDetail FAD WITH (NOLOCK) ON  FAD.PutawayZone = FPZ.PutawayZone
   JOIN LoadPlanDetail LPD WITH (NOLOCK) ON LPD.LoadKey = LP.LoadKey
   JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = LPD.OrderKey
   WHERE  LOC.Facility = CASE WHEN @c_Facility='ALL' THEN LOC.Facility
                         ELSE @c_Facility
                         END
   AND LOC.SectionKey = CASE WHEN @c_Section='ALL' THEN LOC.SectionKey
                        ELSE @c_Section
                        END
   AND FAD.AreaKey = CASE WHEN @c_AreaKey='ALL' THEN FAD.AreaKey
                     ELSE @c_AreaKey
                     END
   AND LP.PROCESSFLAG = 'Y'
   AND LP.Status < '9' -- (Vicky01)
   AND DI.LoadKey = LP.LoadKey
   AND LOC.LocationCategory = 'STAGING'

   OPEN CUR_CAL_PltCase
   FETCH NEXT FROM CUR_CAL_PltCase INTO @c_LoadKey, @c_StorerKey

   WHILE @@FETCH_STATUS<>-1
   BEGIN
      IF NOT EXISTS( SELECT 1
                     FROM #PendingRelease PR
                     WHERE  PR.LoadKey = @c_LoadKey )
      BEGIN
         SELECT @d_CancelDate = MAX(O.DeliveryDate)
         FROM ORDERS O WITH (NOLOCK)
         JOIN LoadPlanDetail LPD WITH (NOLOCK) ON LPD.OrderKey = O.OrderKey
         WHERE LPD.LoadKey = @c_LoadKey
         AND O.DeliveryDate IS NOT NULL

         SELECT TOP 1 @d_PickUpDate = CASE WHEN M.UserDefine07 IS NULL
                                      THEN LP.UserDefine07
                                      END
         FROM LoadPlanDetail LPD WITH (NOLOCK)
         JOIN LoadPlan LP WITH (NOLOCK) ON LP.LoadKey = LPD.LoadKey
         JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = LPD.OrderKey
         LEFT OUTER JOIN MBOLDETAIL M WITH (NOLOCK) ON M.OrderKey = O.OrderKey
         LEFT OUTER JOIN MBOL WITH (NOLOCK) ON  MBOL.MbolKey = M.MbolKey
         WHERE  LPD.LoadKey = @c_LoadKey

         SET @n_TotalCtns = 0
         SET @n_CtnInStage = 0
         SET @n_TotalLooseQTY = 0 -- (ChewKP01)

         DECLARE C_PickTask  CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT P.LOC, P.ID, COUNT (DISTINCT O.ConsigneeKey)
            FROM PickDetail P WITH (NOLOCK)
            JOIN LoadPlanDetail LPD WITH (NOLOCK) ON LPD.OrderKey = P.OrderKey
            JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = P.OrderKey
            JOIN LoadPlan LP WITH (NOLOCK) ON LP.LoadKey = LPD.LoadKey
            JOIN LOC FL WITH (NOLOCK) ON FL.Loc = P.Loc
            JOIN PutawayZone FPZ WITH (NOLOCK) ON FPZ.PutawayZone = FL.PutawayZone
            JOIN AreaDetail FAD WITH (NOLOCK) ON FAD.PutawayZone = FPZ.PutawayZone
            WHERE  LPD.LoadKey = @c_LoadKey
            AND P.STATUS <= '9' -- (Vicky01)
            AND FL.Facility = CASE WHEN @c_Facility='ALL' THEN FL.Facility
                              ELSE @c_Facility
                              END
            AND FL.SectionKey = CASE WHEN @c_Section='ALL' THEN FL.SectionKey
                                ELSE @c_Section
                                END
            AND FAD.AreaKey = CASE WHEN @c_AreaKey='ALL' THEN FAD.AreaKey
                              ELSE @c_AreaKey
                              END
            GROUP BY P.LOC, P.ID, LP.Priority

         OPEN C_PickTask
         FETCH NEXT FROM C_PickTask INTO @c_Loc, @c_ID, @n_ShipTo

         WHILE (@@FETCH_STATUS <> -1)
         BEGIN
            EXEC isp_GetPPKPltCase2
                 @c_loadkey=@c_LoadKey
               , @n_totalcarton=@n_Cartons OUTPUT
               , @n_totalloose=@n_LooseQty OUTPUT   -- (ChewKP01)
               , @c_LOC=@c_LOC
               , @c_ID=@c_ID
               , @c_Picked=''
               , @c_GetTotPallet='N'

            SET @n_TotalCtns = @n_TotalCtns + @n_Cartons
            SET @n_TotalLooseQTY = @n_TotalLooseQTY + @n_LooseQty -- (ChewKP01)

            -- SELECT @c_LaneType '@c_LaneType', @n_Cartons '@n_Cartons'

            FETCH NEXT FROM C_PickTask INTO @c_Loc, @c_ID, @n_ShipTo
         END -- WHILE 1=1
         CLOSE C_PickTask
         DEALLOCATE C_PickTask

         -- Modified by SHONG on 13-May-2010
         -- Only consider Orders.Status NOT IN ('9','CANC')
         SELECT @n_CtnInStage = COUNT(DISTINCT DD.ChildId)
         FROM Dropid D WITH (NOLOCK)
         JOIN DropidDetail DD WITH (NOLOCK) ON DD.Dropid = D.Dropid
         JOIN PackDetail PD WITH (NOLOCK) ON DD.ChildID = PD.LabelNo
         JOIN PackHeader PH WITH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
         JOIN ORDERS O WITH (NOLOCK) ON PH.OrderKey = O.OrderKey
         JOIN LOC L WITH (NOLOCK) ON L.LOC = D.Droploc AND L.LocationCategory = 'STAGING'
         WHERE D.Loadkey = @c_LoadKey
         AND PH.LoadKey = @c_LoadKey
         -- AND O.Status NOT IN ('9','CANC') -- (Vicky01)

        INSERT INTO #PendingRelease (
               LoadKey, StorerKey, CancelDate, PickUpDate, TotCtns, CtnInStage , TotLoose  -- (ChewKP01)
               )
         VALUES ( @c_LoadKey, @c_StorerKey, @d_CancelDate
                , @d_PickUpDate, @n_TotalCtns, @n_CtnInStage  , @n_TotalLooseQTY   -- (ChewKP01)
                )
      END
      FETCH NEXT FROM CUR_CAL_PltCase INTO @c_LoadKey, @c_StorerKey
   END
   CLOSE CUR_CAL_PltCase
   DEALLOCATE CUR_CAL_PltCase

   SELECT LoadKey, StorerKey, ISNULL(CancelDate,'2999-01-01') AS CancelDate, TotCtns, CtnInStage
         , CASE WHEN (TotCtns) > 0 THEN (((CtnInStage * 1.00) / TotCtns)  * 100 )
           ELSE 0 END AS PercentComp
         , ISNULL(PickUpDate,'2999-01-01') AS PickUpDate
         , TotLoose   -- (ChewKP01)
   FROM #PendingRelease
   ORDER BY ISNULL(PickUpDate,'2999-01-01') -- SOS# 238091

GO