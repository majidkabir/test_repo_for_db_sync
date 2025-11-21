SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_GetTMLoadPlanReleasedStatus                    */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.5                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 17-Mar-2010  ChewKP   1.1  ADD in Loose QTY (ChewKP01)               */
/* 04-May-2010  Shong    1.2  Change Carton Picked Calculation          */
/* 06-May-2010  SHONG    1.2  Calling isp_GetPPKPltCase2 instead of     */
/*                            isp_GetPPKPltCase                         */
/* 07-May-2010  Vicky    1.3  Those released but not Pick in progress   */
/*                            should be shown (Vicky01)                 */
/* 27-May-2010  Vicky    1.3  Should consider all the PickDetaiL.Status */
/*                            of a LoadPlan (Vicky02)                   */
/* 21-Dec-2010  NJOW01   1.4  Fix pickedcnts to using pickedcnts1       */
/* 05-Mar-2012  Leong    1.5  SOS# 238091 - Sort by Pickup date         */
/*                                        - Set invisible in PB object  */
/*                                          when date = 2999-01-01      */
/************************************************************************/

CREATE PROC [dbo].[isp_GetTMLoadPlanReleasedStatus]
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
      , @n_PickedCtns      INT
      , @n_UnPickCtns      INT
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
      , @n_CtnInStage      INT
      , @n_AllocatedCtns   INT
      , @n_PickedCtns1     INT

CREATE TABLE #PendingRelease (
     LoadKey     NVARCHAR(10)
   , StorerKey   NVARCHAR(15)
   , CancelDate  DATETIME NULL
   , PickedCtns  INT NULL
   , UnPickCtns  INT DEFAULT 0
   , PercentComp INT DEFAULT 0
   , PickUpDate  DATETIME NULL
   , TotLoose    INT NULL -- (ChewKP01)
   , PickedCtns1 INT DEFAULT 0 -- (Vicky01)
   )

DECLARE CUR_CAL_PltCase  CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT L.LoadKey, P.StorerKey
   FROM PickDetail P WITH (NOLOCK)
   JOIN LOC WITH (NOLOCK) ON LOC.Loc = P.Loc
   JOIN PutawayZone FPZ WITH (NOLOCK) ON FPZ.PutawayZone = LOC.PutawayZone
   JOIN AreaDetail FAD WITH (NOLOCK) ON FAD.PutawayZone = FPZ.PutawayZone
   JOIN LoadPlanDetail LPD WITH (NOLOCK) ON LPD.OrderKey = P.OrderKey
   JOIN LoadPlan L WITH (NOLOCK) ON L.Loadkey = LPD.Loadkey
   WHERE LOC.Facility = CASE WHEN @c_Facility='ALL' THEN LOC.Facility
                        ELSE @c_Facility
                        END
   AND LOC.SectionKey = CASE WHEN @c_Section='ALL' THEN LOC.SectionKey
                        ELSE @c_Section
                        END
   AND FAD.AreaKey = CASE WHEN @c_AreaKey='ALL' THEN FAD.AreaKey
                     ELSE @c_AreaKey
                     END
   AND L.ProcessFLag IN ('Y') AND L.Status < '9'
   ORDER BY L.LoadKey, P.StorerKey

OPEN CUR_CAL_PltCase
FETCH NEXT FROM CUR_CAL_PltCase INTO @c_LoadKey, @c_StorerKey

WHILE @@FETCH_STATUS <> -1
BEGIN
   SET @n_CtnInStage=0
   SELECT @n_CtnInStage = COUNT(DISTINCT DD.ChildId)
   FROM Dropid D WITH (NOLOCK)
   JOIN DropiDDetail DD WITH (NOLOCK) ON DD.Dropid = D.Dropid
   JOIN LOC L WITH (NOLOCK) ON L.LOC = D.Droploc AND L.LocationCategory = 'STAGING'
   WHERE D.Loadkey = @c_LoadKey

   SET @n_AllocatedCtns=0
   SELECT @n_AllocatedCtns = ISNULL(COUNT(DISTINCT P.LabelNo), 0)
   FROM DROPID D WITH (NOLOCK)
   INNER JOIN PACKDETAIL P WITH (NOLOCK) ON P.RefNo = D.DropID
   WHERE D.LabelPrinted = 'Y' AND D.LoadKey = @c_LoadKey

   IF NOT EXISTS( SELECT 1 FROM #PendingRelease PR
                  WHERE PR.LoadKey = @c_LoadKey )
            AND (@n_CtnInStage <> @n_AllocatedCtns)
            OR  (@n_CtnInStage + @n_AllocatedCtns = 0) -- (Vicky01)
   BEGIN
      SELECT @d_CancelDate = MAX(O.DeliveryDate)
      FROM   ORDERS O WITH (NOLOCK)
      JOIN LoadPlanDetail LPD WITH (NOLOCK) ON  LPD.OrderKey = O.OrderKey
      WHERE  LPD.LoadKey = @c_LoadKey AND O.DeliveryDate IS NOT NULL

      SELECT TOP 1 @d_PickUpDate = CASE WHEN M.UserDefine07 IS NULL THEN LP.UserDefine07 END
      FROM   LoadPlanDetail LPD WITH (NOLOCK)
      JOIN LoadPlan LP WITH (NOLOCK) ON LP.LoadKey = LPD.LoadKey
      JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = LPD.OrderKey
      LEFT OUTER JOIN MBOLDETAIL M WITH (NOLOCK) ON M.OrderKey = O.OrderKey
      LEFT OUTER JOIN MBOL WITH (NOLOCK) ON MBOL.MBOLKey = M.MBOLKey
      WHERE  LPD.LoadKey = @c_LoadKey

      SET @n_PickedCtns = 0
      SET @n_PickedCtns1 = 0  -- (Vicky01)
      SET @n_UnPickCtns = 0
      SET @n_TotalLooseQTY = 0 -- (ChewKP01)

      DECLARE C_PickTask  CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT P.LOC, P.ID, COUNT(DISTINCT O.ConsigneeKey)
         FROM PickDetail P WITH (NOLOCK)
         JOIN LoadPlanDetail LPD WITH (NOLOCK) ON LPD.OrderKey = P.OrderKey
         JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = P.OrderKey
         JOIN LoadPlan LP WITH (NOLOCK) ON LP.LoadKey = LPD.LoadKey
         JOIN LOC FL WITH (NOLOCK) ON FL.Loc = P.Loc
         JOIN PutawayZone FPZ WITH (NOLOCK) ON FPZ.PutawayZone = FL.PutawayZone
         JOIN AreaDetail FAD WITH (NOLOCK) ON FAD.PutawayZone = FPZ.PutawayZone
         WHERE  LPD.LoadKey = @c_LoadKey
         AND P.STATUS<='9' -- (Vicky02)
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
         -- Modified by Shong on 04-May-2010
         -- Change Carton Picked Calculation
         -- This Function Only use to get the loose qty
         EXEC isp_GetPPKPltCase2
              @c_loadkey = @c_LoadKey
            , @n_totalcarton = @n_Cartons OUTPUT
            , @n_totalloose = @n_LooseQty OUTPUT   -- (ChewKP01)
            , @c_LOC = @c_LOC
            , @c_ID = @c_ID
            , @c_Picked = 'Y'
            , @c_GetTotPallet = 'N'

         -- Commented by Shong on 04-May-2010
         SET @n_PickedCtns1 = @n_PickedCtns1 + @n_Cartons   -- (Vicky01)
         SET @n_TotalLooseQTY = @n_TotalLooseQTY + @n_LooseQty -- (ChewKP01)

         EXEC isp_GetPPKPltCase2
              @c_loadkey = @c_LoadKey
            , @n_totalcarton = @n_Cartons OUTPUT
            , @n_totalloose = @n_LooseQty OUTPUT   -- (ChewKP01)
            , @c_LOC = @c_LOC
            , @c_ID = @c_ID
            , @c_Picked = 'N'
            , @c_GetTotPallet = 'N'

         SET @n_UnPickCtns = @n_UnPickCtns + @n_Cartons
         SET @n_TotalLooseQTY = @n_TotalLooseQTY + @n_LooseQty -- (ChewKP01)

         -- SELECT @c_LaneType '@c_LaneType', @n_Cartons '@n_Cartons'
         FETCH NEXT FROM C_PickTask INTO @c_Loc, @c_ID, @n_ShipTo
      END -- WHILE 1=1
      CLOSE C_PickTask
      DEALLOCATE C_PickTask

      -- Added by Shong on 04-May-2010
      -- Change Carton Picked Calculation
      SELECT @n_PickedCtns = ISNULL(COUNT(DISTINCT P.LabelNo), 0)
      FROM DROPID D WITH (NOLOCK)
      INNER JOIN PACKDETAIL P WITH (NOLOCK) ON P.RefNo = D.DropID
      WHERE D.LabelPrinted = 'Y'
      AND D.LoadKey = @c_LoadKey

      INSERT INTO #PendingRelease (
            LoadKey, StorerKey, CancelDate, PickUpDate, PickedCtns, UnPickCtns , TotLoose  -- (ChewKP01)
            , PickedCtns1
            )
      VALUES (
              @c_LoadKey, @c_StorerKey, @d_CancelDate, @d_PickUpDate, @n_PickedCtns, @n_UnPickCtns, @n_TotalLooseQTY   -- (ChewKP01)
            , @n_PickedCtns1
            )
   END
   -- Commented by SHONG
   -- I think this part of the code is not execute
   /*
   ELSE
   BEGIN
      UPDATE #PendingRelease
      SET    PickedCtns = PickedCtns + @n_PickedCtns,
      UnPickCtns = UnPickCtns + @n_UnPickCtns
      WHERE  LoadKey = @c_LoadKey
   END
   */
   FETCH NEXT FROM CUR_CAL_PltCase INTO @c_LoadKey, @c_StorerKey
END
CLOSE CUR_CAL_PltCase
DEALLOCATE CUR_CAL_PltCase

SELECT LoadKey, StorerKey, ISNULL(CancelDate,'2999-01-01') AS CancelDate, PickedCtns1, UnPickCtns
     , (PickedCtns1 + UnPickCtns) AS TotCartons -- (Vicky01)
     , CASE WHEN (PickedCtns1 + UnPickCtns) > 0
            THEN FLOOR(PickedCtns1 * 1.00 / (PickedCtns1 + UnPickCtns) * 100 )
            ELSE 0
       END AS PercentComp
     , ISNULL(PickUpDate,'2999-01-01') AS PickUpDate
     , TotLoose   -- (ChewKP01)
FROM #PendingRelease
ORDER BY ISNULL(PickUpDate,'2999-01-01') -- SOS# 238091

GO