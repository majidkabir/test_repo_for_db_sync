SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispUALP01                                          */
/* Creation Date: 11-Aug-2008                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: UK - Republic Cancel Partial Pick Task for TaskManager      */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By: Brio Report                                               */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author      Purposes                                    */
/* 2010-12-03   ChewKP      Revise Coding to avoid DB Locking (ChewKP01)*/
/* 2010-12-09   ChewKP      Update Qty = 0 when Status = '4' in         */
/*                          PickDetail (ChewKP02)                       */
/* 2010-12-13   ChewKP      Add in Trace Info (ChewKP03)                */
/* 2010-12-23   ChewKP      Update OrderDetail.Status = 0 when          */
/*                          QtyAllocated = 0 and QtyPicked = 0(ChewKP04)*/ 
/************************************************************************/
CREATE PROC  [dbo].[ispUALP01]
   @c_Storerkey NVARCHAR(15),
   @c_LoadKey   NVARCHAR(10),
   @c_InOrderKey  NVARCHAR(10),   
   @b_success   INT        OUTPUT,
   @c_errmsg    NVARCHAR(250)  OUTPUT,
   @n_err       INT        OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @n_continue  int,  /* continuation flag
                           1=Continue
                           2=failed but continue processsing
                           3=failed do not continue processing
                           4=successful but skip furthur processing */
      @n_starttcnt int, -- Holds the current transaction count
      --@n_err       int,
      --@c_errmsg    NVARCHAR(250),
      @b_debug     int

   DECLARE
      @c_ReplenStarted NVARCHAR(1),
      @c_PickSlipNo    NVARCHAR(10),
      @c_ReplenDone    NVARCHAR(1), 
      @c_OrderKey      NVARCHAR(10),
      @c_SKU           NVARCHAR(20),
      @n_PackedQty     INT,
      @n_PickedQty     INT, 
      @c_DropID        NVARCHAR(10), 
      @n_PkQty         INT,
      @c_TaskType      NVARCHAR(10),
      @cInit_Final_Zone NVARCHAR(10),
      @c_FinalWCSZone   NVARCHAR(10),
      @c_WCSKey         NVARCHAR(10),
      @c_Facility       NVARCHAR(10),
      @c_PackMatch      NVARCHAR(1),
      @c_PDSKU          NVARCHAR(20),
      @c_PickDetailKey  NVARCHAR(10),
      @c_TraceName      NVARCHAR(80),
      @c_Col5           NVARCHAR(20)
      

      
   SET @b_Success = 1   
   SET @c_PackMatch = '0'   
   SET @b_debug = 0
   SET @c_ReplenStarted='N'
   SET @c_ReplenDone = 'N'
   SET @c_TraceName = 'ispUALP01'
   
   SET @c_TaskType = 'EXCEED'

   SELECT @n_starttcnt=@@TRANCOUNT, @n_continue=1, @n_err=0, @c_errmsg=''

   -- BEGIN TRAN -- (ChewKP01)
   
   -- (ChewKP03)
   SET @c_Col5 = cast(@@TRANCOUNT as varchar)

   INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5) 
   VALUES (@c_TraceName, GetDate(), '', '', 'Start', '', '', '', '', @c_LoadKey, @c_InOrderKey, '', '', @c_Col5)


   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      -- Create Temp Table to Return Results Set for Errors
      CREATE TABLE #TempResult (
         
         ErrorCode         NVARCHAR(10),
         Remarks           NVARCHAR(255)   NULL,
         Loadkey           NVARCHAR(10)    NULL ,
         Orderkey          NVARCHAR(10)    NULL,
         OrderLineNumber   NVARCHAR(5)     NULL,
         SKU               NVARCHAR(20)    NULL,
         Lot               NVARCHAR(10)    NULL,
         Loc               NVARCHAR(10)    NULL,
         Status            NVARCHAR(10)    NULL,
         Qty               INT            NULL,
         DropID            NVARCHAR(18)    NULL,
         LabelPrinted      NVARCHAR(10)    NULL,
         ManifestPrinted   NVARCHAR(10)    NULL         
         )
      
      
      -- If NULL set LoadKey to blank
      IF ISNULL(RTRIM(@c_LoadKey),'') = ''
         SET @c_LoadKey = ''

      -- Check if blank LoadKey
      IF @c_LoadKey = ''
      BEGIN
         SELECT @b_success = 0    
         SELECT @n_continue = 3
         SELECT @n_err = 63000
         SELECT @c_errmsg = 'Empty LoadKey (ispUALP01)'
         GOTO RETURN_SP
      END

      -- ShipFlag = 1
      IF EXISTS (SELECT 1 FROM ORDERS OH WITH (NOLOCK)
                     INNER JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.OrderKey = PD.OrderKey AND PD.Storerkey = @c_Storerkey)
                     WHERE OH.Storerkey = @c_Storerkey
                     AND   OH.OrderKey = @c_InOrderKey
                     AND   PD.ShipFlag = 'Y' )
      BEGIN
         SELECT @b_success = 0
         SELECT @n_continue = 3
         SELECT @n_err = 63010
         SELECT @c_errmsg = 'Not Allowed to Unallocate Shipped Order (ispUALP01)'
         GOTO RETURN_SP
      END
      
      -- Check if Tote Closed? 
      IF EXISTS (SELECT 1 FROM DROPID WITH (NOLOCK)
                  WHERE LoadKey = @c_LoadKey
                  AND   Status = '0' 
                  AND   LabelPrinted = 'Y'
                  AND   ManifestPrinted <> 'Y' )
      BEGIN
         SELECT @b_success = 2
         SELECT @n_continue = 3
         SELECT @n_err = 63005
         SELECT @c_errmsg = 'Found Open Tote Not Close yet. (ispUALP01)'
         
         SET @c_Col5 = cast(@@TRANCOUNT as varchar)

         -- (ChewKP03)
         INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5) 
         VALUES (@c_TraceName, GetDate(), '', '', '', 'DropID', '', '', '', @c_LoadKey, @c_InOrderKey, '', '', @c_Col5)
         
         INSERT INTO #TempResult (ErrorCode, Remarks, DropID, Status, Loadkey, LabelPrinted, ManifestPrinted ) 
         SELECT @n_Err, @c_errmsg, DropID, Status, Loadkey, LabelPrinted, ManifestPrinted
         FROM DROPID WITH (NOLOCK)
         WHERE LoadKey = @c_LoadKey
                  AND   Status = '0' 
                  AND   LabelPrinted = 'Y'
                  AND   ManifestPrinted <> 'Y'
                  
         GOTO RETURN_SP
      END
            
      -- Any Short Pick Records not yet QC?
      IF EXISTS (SELECT 1 FROM PICKDETAIL PD WITH (NOLOCK)
                INNER JOIN ORDERS OH WITH (NOLOCK) ON (OH.OrderKey = PD.OrderKey)
                WHERE OH.Storerkey = @c_Storerkey
                AND   OH.LoadKey = @c_LoadKey 
                AND   OH.OrderKey = @c_InOrderKey                 
                AND   PD.Status = '4' 
                AND   PD.Qty > 0 )
      BEGIN
         SET @c_Col5 = cast(@@TRANCOUNT as varchar)

         -- (ChewKP03)
         INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5) 
         VALUES (@c_TraceName, GetDate(), '', '', 'SP OrderKey', '', '', '', '', @c_InOrderKey, '', '', '', @c_Col5)
      
         BEGIN TRAN
            
         Delete PickDetail WITH (ROWLOCK)
      WHERE Orderkey = @c_InOrderKey
         AND   Storerkey = @c_Storerkey
         AND   Status = '4' 
         IF @@ERROR <> 0 
         BEGIN
               SELECT @b_success = 0
               SELECT @n_continue = 3
               SELECT @n_err = 63022
               SELECT @c_errmsg = 'Error UPDATE #PICKDETAIL (ispUALP01)'
               GOTO RETURN_SP
         END
         ELSE 
         BEGIN
            COMMIT TRAN
         END
      END
      
      

      SET @c_Facility = ''
      SELECT @c_Facility = Facility FROM LOADPLAN WITH (NOLOCK)
      WHERE Loadkey = @c_LoadKey


      -- Is It Over Packed?
      -- Calculate Total Packed Qty for Load
      IF OBJECT_ID('tempdB..#Packed') IS NOT NULL 
         drop table #Packed
   
      SELECT ph.OrderKey, pd.SKU, SUM(PD.Qty) AS Qty 
      INTO #Packed
      FROM PackDetail pd WITH (NOLOCK)
      JOIN PackHeader ph WITH (NOLOCK) ON ph.PickSlipNo = pd.PickSlipNo 
      JOIN ORDERS o (nolock) ON o.OrderKey = ph.OrderKey 
      WHERE o.LoadKey = @c_LoadKey
      AND   o.OrderKey = @c_InOrderKey
      GROUP BY ph.OrderKey, pd.SKU
      

      -- Calculate Total Picked Qty for Load 
      IF OBJECT_ID('tempdB..#Picked') IS NOT NULL 
         drop table #Picked
   
      SELECT pd.OrderKey, pd.SKU, SUM(PD.Qty) AS Qty 
      INTO #Picked 
      FROM PickDetail pd  (NOLOCK)
      JOIN ORDERS o  (NOLOCK) ON o.OrderKey = pd.OrderKey 
      WHERE o.LoadKey = @c_LoadKey
      AND o.OrderKey = @c_InOrderKey
      AND pd.Status BETWEEN '5' AND '8' 
      AND pd.Qty > 0 
      group by pd.OrderKey, pd.SKU

      -- List Pick & Pack Not Match -every thing 
      SET @c_errmsg = ''
      DECLARE Cursor_OverPack CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT ISNULL(B.OrderKey, A.OrderKey),
             ISNULL(B.SKU, A.SKU), A.Qty PackQty, B.Qty PickQty
      FROM #Packed A 
      FULL OUTER JOIN #Picked B ON A.OrderKey = B.OrderKey AND A.SKU = B.SKU 
      WHERE A.Qty > B.Qty
      ORDER BY ISNULL(B.OrderKey, A.OrderKey)
      
      OPEN Cursor_OverPack 
      
      FETCH NEXT FROM Cursor_OverPack INTO @c_OrderKey, @c_SKU, @n_PackedQty, @n_PickedQty
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         --SET @c_errmsg = ISNULL(RTRIM(@c_errmsg), '') + '( Order#: ' + @c_OrderKey + ' SKU: ' + @c_SKU + ' ).' + master.dbo.fnc_GetCharASCII(13)
         SELECT @n_err = 63009
         
         SELECT @c_errmsg = 'Over Packed Found: ' + RTRIM(@c_errmsg) + ' (ispUALP01)'
         
         -- (ChewKP03)
         SET @c_Col5 = cast(@@TRANCOUNT as varchar)

         INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5) 
         VALUES (@c_TraceName, GetDate(), '', '', 'OverPack', '', '', '', '', @c_OrderKey, @c_SKU, @n_PickedQty, '', @c_Col5)
         
         INSERT INTO #TempResult (ErrorCode, Remarks, Loadkey, Orderkey, OrderLineNumber, SKU, Lot, Loc, Status, Qty ) 
         SELECT @n_Err, @c_errmsg, @c_Loadkey, @c_OrderKey, '', @c_SKU, '', '', '', @n_PickedQty
         
         
         FETCH NEXT FROM Cursor_OverPack INTO @c_OrderKey, @c_SKU, @n_PackedQty, @n_PickedQty
      END
      CLOSE Cursor_OverPack 
      DEALLOCATE Cursor_OverPack 

      
      
      IF ISNULL(RTRIM( @c_errmsg ), '') <> '' 
      BEGIN
         SELECT @b_success = 2
         SELECT @n_continue = 3
         --SELECT @n_err = 63009
         --SELECT @c_errmsg = 'Over Packed Found: ' + RTRIM(@c_errmsg) + ' (ispUALP01)'
         GOTO RETURN_SP
      END


      /* ----------------------------------------------- */
      /* START UNALLOCATION                              */
      /* ----------------------------------------------- */
      IF OBJECT_ID('tempdb..#PackDetail') IS NOT NULL
         DROP TABLE #PackDetail
      
      CREATE TABLE #PackDetail (
         REFROW      INT IDENTITY(1,1) PRIMARY KEY,
         OrderKey    NVARCHAR(10), 
         DropID      NVARCHAR(18), 
         SKU         NVARCHAR(20), 
         Qty         INT)
         
      IF OBJECT_ID('tempdb..#PickDetail') IS NOT NULL
         DROP TABLE #PickDetail
         
      CREATE TABLE #PickDetail (
         REFROW      INT IDENTITY(1,1) PRIMARY KEY,
         PickDetailKey NVARCHAR(10),
         OrderKey    NVARCHAR(10), 
         DropID      NVARCHAR(18), 
         SKU         NVARCHAR(20), 
         Qty         INT,
         ValidFlag   NVARCHAR(1))
      
      CREATE TABLE #DROPID (
         REFROW      INT IDENTITY(1,1) PRIMARY KEY,
         DropID            NVARCHAR(18),
         Loadkey           NVARCHAR(10),
         LabelPrinted      NVARCHAR(10),
         ManifestPrinted   NVARCHAR(10),
         Status            NVARCHAR(10))
         
-- (ChewKP01)      
--      WHILE @@TRANCOUNT > 0
--      BEGIN
--         COMMIT TRAN
--      END 
         
      DECLARE Cursor_Unallocate CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT ISNULL(B.OrderKey, A.OrderKey),
             ISNULL(B.SKU, A.SKU), 
             ISNULL(A.Qty,0) PackQty, 
             ISNULL(B.Qty,0) PickQty
      FROM #Packed A 
      FULL OUTER JOIN #Picked B ON A.OrderKey = B.OrderKey AND A.SKU = B.SKU 
      WHERE A.Qty IS NULL OR B.Qty IS NULL OR A.Qty <> B.Qty
      ORDER BY ISNULL(B.OrderKey, A.OrderKey)
      
      OPEN Cursor_Unallocate 
      
      FETCH NEXT FROM Cursor_Unallocate INTO @c_OrderKey, @c_SKU, @n_PackedQty, @n_PickedQty
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @n_PackedQty = 0 AND @n_PickedQty > 0 
         BEGIN
            -- (ChewKP03)
            SET @c_Col5 = cast(@@TRANCOUNT as varchar)

            INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5) 
            VALUES (@c_TraceName, GetDate(), '', '', 'Pack=0 Pick>0', '', '', '', '', @c_OrderKey, @c_SKU, '', '', @c_Col5)
         
            BEGIN TRAN -- (ChewKP01)
            
            DELETE FROM PICKDETAIL  
            WHERE Orderkey = @c_Orderkey 
            AND   SKU      = @c_SKU
            AND   Status   < '9'                  
            IF @@ERROR <> 0 
            BEGIN
                  SELECT @b_success = 0
                  SELECT @n_continue = 3
                  SELECT @n_err = 63021
                  SELECT @c_errmsg = 'Error DELETE #PICKDETAIL (ispUALP01)'
                  GOTO RETURN_SP
            END
            ELSE -- (ChewKP01)
            BEGIN
               COMMIT TRAN
            END
         END
         ELSE IF @n_PackedQty > 0 AND @n_PickedQty > 0  
         BEGIN
            TRUNCATE TABLE #PackDetail
            TRUNCATE TABLE #PickDetail
            TRUNCATE TABLE #DropID
            
            INSERT INTO #PackDetail (OrderKey, DropID, SKU, Qty)
            SELECT PH.OrderKey, PD.DropID, PD.SKU, SUM(PD.Qty) 
            FROM   PACKDETAIL PD (NOLOCK) 
            JOIN   PACKHEADER PH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo 
            WHERE  PH.OrderKey = @c_OrderKey
              AND  PD.SKU = @c_SKU 
            GROUP BY PH.OrderKey, PD.DropID, PD.SKU

            INSERT INTO #PICKDETAIL (PickDetailKey, OrderKey, SKU, DropID, Qty, ValidFlag)
            SELECT PickDetailKey, OrderKey, SKU, 
                   --CASE WHEN CASEID <> '' AND ALTSKU <> '' THEN CASEID ELSE DropID END, 
                   CASE WHEN CASEID <> '' AND ALTSKU <> '' THEN ALTSKU ELSE DropID END, 
                   Qty, 'N' 
            FROM   PICKDETAIL WITH (NOLOCK) 
            WHERE  OrderKey = @c_OrderKey 
              AND  SKU = @c_SKU   
              AND  STATUS BETWEEN '5' AND '8' 

            DECLARE Cursor_PackDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT DropID, Qty FROM #PackDetail 

            OPEN Cursor_PackDetail
            
            FETCH NEXT FROM Cursor_PackDetail INTO @c_DropID, @n_PkQty
            WHILE @@FETCH_STATUS <> -1
            BEGIN
--               IF (SELECT SUM(QTY) FROM #PICKDETAIL 
--                   WHERE DropID = @c_DropID 
--                   AND SKU = @c_SKU 
--                   AND OrderKey = @c_OrderKey) =  @n_PkQty
               IF (SELECT SUM(QTY) FROM #PICKDETAIL 
                   WHERE SKU = @c_SKU
                   AND OrderKey = @c_OrderKey
                   AND DropID = @c_DropID ) =  @n_PkQty
               BEGIN
                  UPDATE #PICKDETAIL
                     SET ValidFlag = 'Y'  
                  WHERE DropID = @c_DropID 
                   AND SKU = @c_SKU 
                   AND OrderKey = @c_OrderKey
                   
                  IF @@ERROR <> 0 
                  BEGIN
                     SELECT @b_success = 0
                     SELECT @n_continue = 3
                     SELECT @n_err = 63020
                     SELECT @c_errmsg = 'Error UPDATE #PICKDETAIL (ispUALP01)'
                     GOTO RETURN_SP
                  END
               END 
          
               
               FETCH NEXT FROM Cursor_PackDetail INTO @c_DropID, @n_PkQty
            END
            CLOSE Cursor_PackDetail
            DEALLOCATE Cursor_PackDetail 


            -- DELETE PICKDETAIL FROM #PICKDETAIL WHERE ValidFlag = 'N'
            -- (ChewKP03)
            SET @c_Col5 = cast(@@TRANCOUNT as varchar)

            INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5) 
            VALUES (@c_TraceName, GetDate(), '', '', 'UPD PD Flag=N', '', '', '', '', @c_PickSlipNo, '', @c_PDSKU, '', @c_Col5)
            
            BEGIN TRAN
               
            DELETE PD 
            FROM PICKDETAIL PD WITH (NOLOCK)
            JOIN #PickDetail PD2 ON PD2.PickDetailKey = PD.PickDetailKey 
            WHERE PD2.ValidFlag = 'N'
            IF @@ERROR <> 0 
            BEGIN
               SELECT @b_success = 0
               SELECT @n_continue = 3
               SELECT @n_err = 63012
               SELECT @c_errmsg = 'Error DELETE PickDetail (ispUALP01)'
               GOTO RETURN_SP
            END
            ELSE -- (ChewKP01)
            BEGIN 
               COMMIT TRAN
            END
            
         END
         ELSE IF @n_packedQty > 0 AND @n_PickedQty = 0
         BEGIN
               -- DELETE PACKDETAIL WHEN Pick Qty = 0 
               DECLARE Cursor_PackDetail2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT  PD.PICKSLIPNO, PD.SKU 
               FROM PACKDETAIL PD WITH (NOLOCK)
               INNER JOIN PACKHEADER PH (NOLOCK) ON PH.PICKSLIPNO = PD.PICKSLIPNO
               WHERE PD.SKU = @c_SKU
               AND PH.ORDERKEY = @c_OrderKey

               OPEN Cursor_PackDetail2 
      
               FETCH NEXT FROM Cursor_PackDetail2 INTO @c_PickSlipNo, @c_PDSKU
               WHILE @@FETCH_STATUS <> -1
               BEGIN
               
               -- (ChewKP03)
               SET @c_Col5 = cast(@@TRANCOUNT as varchar)

               INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5) 
               VALUES (@c_TraceName, GetDate(), '', '', 'UPD PACKKDETAIL', '', '', '', '', @c_PickSlipNo, '', @c_PDSKU, '', @c_Col5)
               
               BEGIN TRAN -- (ChewKP01)
                  
               UPDATE PackDetail WITH (ROWLOCK) 
               SET Qty = 0
               WHERE PickSlipNo = @c_PickSlipNo
               AND SKU = @c_PDSKU
               
               IF @@ERROR <> 0 
               BEGIN
                  SELECT @b_success = 0
                  SELECT @n_continue = 3
                  SELECT @n_err = 63021
                  SELECT @c_errmsg = 'Error UPDATE PackDetail (ispUALP01)'
                  GOTO RETURN_SP
               END
               ELSE -- (ChewKP01)
               BEGIN
                  COMMIT TRAN
               END
      
               FETCH NEXT FROM Cursor_PackDetail2 INTO @c_PickSlipNo, @c_PDSKU
               END
               
               CLOSE Cursor_PackDetail2 
               DEALLOCATE Cursor_PackDetail2 
         END
         
            FETCH NEXT FROM Cursor_Unallocate INTO @c_OrderKey, @c_SKU, @n_PackedQty, @n_PickedQty
      END
         
      CLOSE Cursor_Unallocate 
      DEALLOCATE Cursor_Unallocate 
      
      
      -- (ChewKP03)
      SET @c_Col5 = cast(@@TRANCOUNT as varchar)

      INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5) 
      VALUES (@c_TraceName, GetDate(), '', '', 'DEL PICKKDETAIL', 'Status 0,3,4', '', '', '', @c_PickDetailKey, '', '', '', @c_Col5)
            
      BEGIN TRAN -- (ChewKP01)
      
      DELETE FROM PICKDETAIL
      FROM PICKDETAIL PD  WITH (NOLOCK)
      INNER JOIN ORDERS OH WITH (NOLOCK) ON (OH.OrderKey = PD.OrderKey)
       WHERE OH.Storerkey = @c_Storerkey
       AND   OH.LoadKey = @c_LoadKey 
       AND   OH.Orderkey = @c_InOrderKey
       AND   PD.Status Between '0' and '4'
           
      
      IF @@ERROR <> 0 
      BEGIN
         SELECT @b_success = 0
         SELECT @n_continue = 3
         SELECT @n_err = 63018
         SELECT @c_errmsg = 'Error DELETE PickDetail (ispUALP01)'
         GOTO RETURN_SP
      END
      ELSE -- (ChewKP01)
      BEGIN
         COMMIT TRAN
      END
      
      /* ----------------------------------------------- */
      /* Update OrderDetail.Status = 0 when              */
      /* QtyAllocated = 0 and QtyPicked = 0 (ChewKP04)   */          
      /* ----------------------------------------------- */
      
      IF EXISTS ( SELECT 1 FROM OrderDetail WITH (NOLOCK)
                  WHERE Orderkey = @c_InOrderKey
                  AND Status = '3'
                  AND QtyAllocated = 0
                  AND QtyPicked = 0 )
      BEGIN
         INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5) 
         VALUES (@c_TraceName, GetDate(), '', '', 'UPD ORDSTATUS', '', '', '', '', @c_InOrderKey, '', '', '', @c_Col5)
      
         BEGIN TRAN
            
         UPDATE OrderDetail 
         SET STATUS = 0 , TrafficCop = NULL
         WHERE Orderkey = @c_InOrderKey
         AND Status = '3'
         AND QtyAllocated = 0
         AND QtyPicked = 0
         
                  
         IF @@ERROR <> 0 
         BEGIN
            SELECT @b_success = 0
            SELECT @n_continue = 3
            SELECT @n_err = 63023
            SELECT @c_errmsg = 'Error Update OrderDetail (ispUALP01)'
            GOTO RETURN_SP
         END
         ELSE -- (ChewKP01)
         BEGIN
            COMMIT TRAN
         END
         
      END
      
      
      
      
      --- Clean ALL REMAINING RECORDS , DropID , WCSRouting , PickDetail
      TRUNCATE TABLE #DROPID

      INSERT INTO #DROPID ( DropID , Loadkey , LabelPrinted, ManifestPrinted, Status )
      SELECT D.DropID , D.Loadkey , D.LabelPrinted, D.ManifestPrinted, D.Status 
      FROM DropID D WITH (NOLOCK)
      WHERE  NOT EXISTS (SELECT 1 FROM PickDetail PD WITH (NOLOCK) 
                         INNER JOIN LoadPlanDetail LPD WITH (NOLOCK) ON LPD.Orderkey = PD.Orderkey 
                                AND LPD.Loadkey = @c_Loadkey
                         WHERE D.DropID = PD.DropID  )
        AND  D.Loadkey = @c_Loadkey
        AND  D.Status <> '9'

      DECLARE Cursor_DROPID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DropID
      FROM #DROPID 
      WHERE Loadkey = @c_Loadkey
      GROUP BY DropID, Loadkey
      
      OPEN Cursor_DROPID 
      
      FETCH NEXT FROM Cursor_DROPID INTO @c_DropID
      WHILE @@FETCH_STATUS <> -1
      BEGIN

           /* ----------------------------------------------- */
           /* UPDATE  DropID Records                          */
           /* ----------------------------------------------- */
           
           -- (ChewKP03)
            SET @c_Col5 = cast(@@TRANCOUNT as varchar)

           INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5) 
           VALUES (@c_TraceName, GetDate(), '', '', 'UPD DropID', '', '', '', '', @c_DropID, @c_Loadkey, '', '', @c_Col5)
         
           BEGIN TRAN -- (ChewKP01)
            
              UPDATE DROPID 
              SET STATUS = '9'
              WHERE DROPID = @c_DropID
                AND Loadkey = @c_Loadkey
                AND Status <> '9'
              
              IF @@ERROR <> 0 
              BEGIN
                  SELECT @b_success = 0
                  SELECT @n_continue = 3
                  SELECT @n_err = 63013
                  SELECT @c_errmsg = 'Error Update DropID (ispUALP01)'
                  GOTO RETURN_SP
              END
              ELSE -- (ChewKP01)
              BEGIN
                  COMMIT TRAN
              END

           /* ----------------------------------------------- */
           /* INSERT DELETE for WCSRouting Records            */
           /* ----------------------------------------------- */
      
           IF EXISTS ( SELECT 1 FROM WCSROUTING  WITH (NOLOCK) WHERE ToteNo = @c_DropID AND Status = '0' )
           BEGIN
                  
                -- Start   
                SET @cInit_Final_Zone = ''  
                SET @c_FinalWCSZone = ''  
                SELECT TOP 1 @c_FinalWCSZone = Final_Zone ,  
                       @cInit_Final_Zone = Initial_Final_Zone  
                FROM dbo.WCSRouting WITH (NOLOCK)  
                WHERE ToteNo = @c_DropID  
                     AND ActionFlag = 'I'  
                ORDER BY WCSKey Desc  
                -- End   
                      
                EXECUTE nspg_GetKey       
                'WCSKey',       
                10,       
                @c_WCSKey OUTPUT,       
                @b_success OUTPUT,       
                @n_err    OUTPUT,       
                @c_ErrMsg OUTPUT        
                      
                IF @n_Err<>0      
                BEGIN    
                    SELECT @b_success = 0  
                    SELECT @n_continue = 3
                    SELECT @n_err = 63014
                    SELECT @c_errmsg = 'Gen WCSKey Failed (ispUALP01)'
                    GOTO RETURN_SP  
                END        
                
                -- (ChewKP03)
                SET @c_Col5 = cast(@@TRANCOUNT as varchar)

                INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5) 
                VALUES (@c_TraceName, GetDate(), '', '', 'INS WCS', '', '', '', '', @c_DropID, @c_WCSKey, '', '', @c_Col5)
           
                BEGIN TRAN
                        
                INSERT INTO WCSRouting      
                  (      
                    WCSKey          ,ToteNo          ,Initial_Final_Zone          ,Final_Zone      
                   ,ActionFlag      ,StorerKey       ,Facility                    ,OrderType      
                   ,TaskType         )      
                VALUES      
                  ( @c_WCSKey       ,@c_DropID          ,ISNULL(@cInit_Final_Zone,'')        
                   ,ISNULL(@c_FinalWCSZone,'')    
                   ,'D'             ,@c_StorerKey       ,@c_Facility       ,''      
                   ,@c_TaskType      
                  ) -- Delete        
                      
                SELECT @n_Err = @@ERROR        
                      
                IF @n_Err<>0      
                BEGIN   
                    SELECT @b_success = 0   
                    SELECT @n_continue = 3
                    SELECT @n_err = 63015
                    SELECT @c_errmsg = 'Insert WCSRouting Failed(ispUALP01)'
                    GOTO RETURN_SP   
                END
                ELSE -- (ChewKP01)
                BEGIN
                     COMMIT TRAN
                END      
                      
                -- (ChewKP03)      
                SET @c_Col5 = cast(@@TRANCOUNT as varchar)

                INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5) 
                VALUES (@c_TraceName, GetDate(), '', '', 'UPD WCS', '', '', '', '', @c_DropID, '', '', '', @c_Col5)
                      
                -- Update WCSRouting.Status = '5' When Delete        
                BEGIN TRAN -- (ChewKP01)
                  
                UPDATE WCSRouting WITH (ROWLOCK)      
                SET    STATUS = '5'      
                WHERE  ToteNo = @c_DropID        
                      
                SELECT @n_Err = @@ERROR        
                      
                IF @n_Err<>0      
                BEGIN      
                    SELECT @b_success = 0 
                    SELECT @n_continue = 3
                    SELECT @n_err = 63016
                    SELECT @c_errmsg = 'Upd WCS Failed (ispUALP01)'
                    GOTO RETURN_SP   
                END     
                ELSE -- (ChewKP01)
                BEGIN
                     COMMIT TRAN
                END  
              
                -- INSERT INTO WCS System
                EXEC dbo.isp_WMS2WCSRouting        
                       @c_WCSKey,        
                 @c_StorerKey,        
                       @b_Success OUTPUT,        
                       @n_Err  OUTPUT,         
                       @c_ErrMsg OUTPUT        
                       
                IF @n_Err <> 0         
                BEGIN      
                    SELECT @b_success = 0   
                    SELECT @n_continue = 3
                    --SELECT @n_err = 63016
                    SELECT @c_errmsg = CONVERT(CHAR(5),ISNULL(@n_Err,0)) + ' ' + ISNULL(RTRIM(@c_ErrMsg), '') + '(ispUALP01)'
                    GOTO RETURN_SP        
                END        
           
           END -- EXISTS ( SELECT 1 FROM WCSROUTING  WITH (NOLOCK) WHERE ToteNo = @c_DropID AND Status = '0')

     FETCH NEXT FROM Cursor_DROPID INTO @c_DropID
      END
     CLOSE Cursor_DROPID
     DEALLOCATE Cursor_DROPID 
      
   END -- IF @n_continue = 1 OR @n_continue = 2
   
   RETURN_SP:
   WHILE @@TRANCOUNT < @n_starttcnt
   BEGIN
      BEGIN TRAN
   END        
   -- (ChewKP03)
   SET @c_Col5 = cast(@@TRANCOUNT as varchar)

   INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5) 
   VALUES (@c_TraceName, GetDate(), GetDate(), '', 'End', '', '', '', '', @c_LoadKey, @c_InOrderKey, '', '', @c_Col5)
   
   /* ----------------------------------------------- */
   /* RETURN Result Set                               */
   /* ----------------------------------------------- */
      SELECT * FROM  #TempResult Order by Orderkey 

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      
   IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
            COMMIT TRAN
         END
      END
--      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispUALP01'
--      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO