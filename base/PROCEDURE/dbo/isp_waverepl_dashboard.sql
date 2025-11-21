SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_WaveRepl_Dashboard                             */
/* Creation Date: 18-FEB-2013                                           */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#266624 - Replenishment Dashboard                        */
/*                                                                      */
/* Called By: r_dw_waverepl_dashboard                                   */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_WaveRepl_Dashboard] (
         @c_Storerkey NVARCHAR(15)
      ,  @c_Facility  NVARCHAR(5)
)
AS
BEGIN
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @c_WaveKey            NVARCHAR(10)
         , @c_Sku                NVARCHAR(20)
         , @c_Brand              NVARCHAR(30)
         , @c_ListKey            NVARCHAR(10)
         , @c_Status             NVARCHAR(10)
         , @n_Qty                INT
         , @n_UCCQty             FLOAT
         , @c_FinalLoc           NVARCHAR(10)
         , @c_PickLoc            NVARCHAR(10)
         , @c_FromLocType        NVARCHAR(10)
         , @c_ToLocType          NVARCHAR(10)
         , @n_NoOfCarton         INT
         , @n_CTNOnTrolley       INT
         , @n_TotalCartonNo      INT
         , @n_CartonOnInduction  INT
         , @n_CartonOnTrolley    INT
         , @n_CartonCompleted    INT
         , @n_CompletedPctg      DECIMAL(5,2)
         , @n_NoOfTrolleyUser    INT
         , @n_TotalQtyPiece      INT
         , @n_QtyPieceLeft       INT
         , @c_Short              NVARCHAR(3)
         
         , @c_TrolleyNo          NVARCHAR(10)


   SET @c_WaveKey             = ''
   SET @c_Sku                 = ''
   SET @c_Brand               = ''
   SET @c_ListKey             = ''
   SET @c_Status              = '0'
   SET @n_Qty                 = 0
   SET @n_UCCQty              = 0.00
   SET @c_FinalLoc            = ''
   SET @c_PickLoc             = ''
   SET @c_FromLocType         = ''
   SET @c_ToLocType           = ''
   SET @n_NoOfCarton          = 0
   SET @n_CTNOnTrolley        = 0
   SET @n_TotalCartonNo       = 0
   SET @n_CartonOnInduction   = 0
   SET @n_CartonOnTrolley     = 0
   SET @n_CartonCompleted     = 0
   SET @n_CompletedPctg       = 0.00
   SET @n_NoOfTrolleyUser     = 0
   SET @n_TotalQtyPiece       = 0
   SET @n_QtyPieceLeft        = 0
   SET @c_Short               = ''

   SET @c_TrolleyNo           = ''

   CREATE TABLE #TEMP_REPL
      (  WaveKey           NVARCHAR(10)
      ,  Brand             NVARCHAR(30)
      ,  TotalCartonNo     INT
      ,  CartonOnInduction INT
      ,  CartonOnTrolley   INT
      ,  CartonCompleted   INT
      ,  CompletedPctg     FLOAT
      ,  NoOfTrolleyUser   INT
      ,  TotalQtyPiece     INT
      ,  QtyPieceLeft      INT
      ,  Short             NVARCHAR(3)
      )

   /* REMARKS: 
   (1) Defination:
       -- TASKDETAIL.UOMQty = UCC CaseCnt (UCC.Qty)
       -- TASKDETAIL.UOM = '2' = Full Case/Carton
       -- Induction Loc => Conveyor
       -- DYNPICKP (DP) a loc that a case being opened and able to finish picking for all orders. 
       -- DYNPPICK (DPP) that will be left over after pick
   (2) Flow:
       -- Allocation 
          -- LAUCH Order - Allocate from BULK first then DPP
          -- RETAILER Order - Allocate from DPP then BULK
       -- Release ReplenWave Task will calc to final Loc
          -- Taskdetail with from VNA loc and To Loc (DPP/DP)
          -- If LAUNCH order, will create a replen task from DPP loc to DP loc
       -- RDT Picking: VNA(fromloc)->PND (transit loc)->Induction Loc->Trolly->DP/DPP(completed loc)
          -- Picker pull carton / pallet from BULK (VNR) Loc and put it into a dropid (empty pallet), when the dropid is full then split taskdetail & 
             Pickdetail. Split Qty as well 
          -- RDT will create task for PND (transit loc) -> Induction loc (qty = 0, Pickdetail does not have record)
             -- Taskdetail.Listkey will be created and link all to main tasks(listkey for main and sub task are same) 
             -- Main tasks toloc = trasit loc, final loc = actual Pick to Loc (DP/DPP)
             -- ** Optional: If Carton pick from VNA direct to induction loc, no sub task creates
             -- ** VFCDC always has transit Loc
          -- When Carton finishes put to Induction, taskdetail.status = '9' 
             -- Final Loc for Full Carton = Induction loc
          -- For Case with UOM = '6' or '7', it will move to Trolley
          -- Trolley contains ucc carton and move to final loc (DPP or DP loc)
          -- Final Loc (DPP or DP loc)
             -- There are 2 different DP loc, 1 for LAUNCH order and 1 for RETAILER order
             -- Both LAUNCH & RETAILER Orders share 1 DPP loc. 
          -- *** RDT will update Pickdetail.loc when carton move to different loc. 
   */
   DECLARE CUR_REPL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT WAVEDETAIL.Wavekey
         ,Brand = ISNULL(RTRIM(SKU.BUSR5),'')
         ,Short = MAX(CASE WHEN PickDetail.Status = '4' THEN 'YES' ELSE 'NO' END)
   FROM WAVEDETAIL WITH (NOLOCK) 
   JOIN ORDERS     WITH (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERS.Orderkey)
   JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = PICKDETAIL.Orderkey)
   JOIN SKU        WITH (NOLOCK) ON (PICKDETAIL.Storerkey  = SKU.Storerkey)
                                 AND(PICKDETAIL.Sku = SKU.Sku)
   WHERE ORDERS.Facility = CASE WHEN @c_Facility = 'ALL' THEN ORDERS.Facility ELSE @c_Facility END
   AND   ORDERS.Storerkey= CASE WHEN @c_Storerkey= 'ALL' THEN ORDERS.Storerkey ELSE @c_Storerkey END
   GROUP BY WAVEDETAIL.Wavekey
         ,  ISNULL(RTRIM(SKU.BUSR5),'')

   OPEN CUR_REPL      
         
   FETCH NEXT FROM CUR_REPL INTO @c_Wavekey
                              ,  @c_Brand
                              ,  @c_Short
                             
   WHILE @@FETCH_STATUS <> -1      
   BEGIN
      SET @n_TotalCartonNo     = 0
      SET @n_CartonOnInduction = 0
      SET @n_CartonOnTrolley   = 0
      SET @n_CartonCompleted   = 0
      SET @n_TotalQtyPiece     = 0
      SET @n_QtyPieceLeft      = 0
      SET @n_CompletedPctg     = 0

      --RELEASE TASK
      DECLARE CUR_CARTON CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT Qty        = SUM(TASKDETAIL.Qty)
            ,UCCQty     = ISNULL(TASKDETAIL.UOMQty,0)
            ,Status     = ISNULL(RTRIM(TASKDETAIl.Status),'')
            ,FinalLoc   = CASE WHEN ISNULL(RTRIM(TASKDETAIl.Status),'') = '9' AND ISNULL(RTRIM(TASKDETAIL.ListKey),'') = ''
                               THEN ISNULL(RTRIM(TASKDETAIL.ToLoc),'')
                               ELSE ISNULL(RTRIM(TASKDETAIL.FinalLoc),'')
                               END
            ,PickLoc    = ISNULL(RTRIM(PICKDETAIL.Loc),'')
            ,FromLocTyoe= ISNULL(RTRIM(FL.LocationType),'')
            ,ToLocType  = ISNULL(RTRIM(TL.LocationType),'') 
            ,CTNOnTrolley = COUNT(DISTINCT TLY.UCCNo) 
      FROM TASKDETAIL WITH (NOLOCK) 
      JOIN PICKDETAIL WITH (NOLOCK) ON (TASKDETAIL.Taskdetailkey = PICKDETAIL.Taskdetailkey)
      JOIN SKU        WITH (NOLOCK) ON (PICKDETAIL.Storerkey  = SKU.Storerkey)
                                    AND(PICKDETAIL.Sku = SKU.Sku)
      JOIN LOC FL     WITH (NOLOCK) ON (TASKDETAIL.FromLoc = FL.Loc)
      JOIN LOC TL     WITH (NOLOCK) ON (TASKDETAIL.ToLoc = TL.Loc)
      LEFT JOIN RDT.RDTTrolleyLog TLY WITH (NOLOCK) ON (TASKDETAIL.TaskDetailKey = TLY.TaskDetailKey)
      WHERE TASKDETAIL.Wavekey = @c_Wavekey
      AND   SKU.BUSR5 = @c_Brand
      AND   TASKDETAIL.TaskType = 'RPF'
      GROUP BY ISNULL(TASKDETAIL.UOMQty,0)
            ,  ISNULL(RTRIM(TASKDETAIl.Status),'')
            ,  CASE WHEN ISNULL(RTRIM(TASKDETAIl.Status),'') = '9' AND ISNULL(RTRIM(TASKDETAIL.ListKey),'') = ''
                    THEN ISNULL(RTRIM(TASKDETAIL.ToLoc),'')
                    ELSE ISNULL(RTRIM(TASKDETAIL.FinalLoc),'')
                    END
            ,  ISNULL(RTRIM(PICKDETAIL.Loc),'')
            ,  ISNULL(RTRIM(FL.LocationType),'')
            ,  ISNULL(RTRIM(TL.LocationType),'') 

      OPEN CUR_CARTON      
            
      FETCH NEXT FROM CUR_CARTON INTO @n_Qty
                                    , @n_UCCQty
                                    , @c_Status
                                    , @c_FinalLoc
                                    , @c_PickLoc
                                    , @c_FromLocType
                                    , @c_ToLocType
                                    , @n_CTNOnTrolley

      WHILE @@FETCH_STATUS <> -1      
      BEGIN
         IF @c_FromLocType = 'DYNPPICK' AND @c_FromLocType = 'DYNPICKP'
         BEGIN
            SET @n_TotalQtyPiece = @n_TotalQtyPiece + @n_Qty
   
            IF @c_Status < '9'
            BEGIN
               SET @n_QtyPieceLeft = @n_QtyPieceLeft + @n_Qty
            END 
         END
         ELSE
         BEGIN
            SET @n_UCCQty = CASE WHEN @n_UCCQty = 0 THEN 1 ELSE @n_UCCQty END

            SET @n_NoOfCarton = CEILING(@n_Qty / @n_UCCQty)

            SET @n_TotalCartonNo = @n_TotalCartonNo + @n_NoOfCarton

            IF @c_Status = '9'
            BEGIN
               SET @n_CartonOnInduction = @n_CartonOnInduction + @n_NoOfCarton

               IF @c_FinalLoc = @c_PickLoc
               BEGIN
                  SET @n_CartonCompleted = @n_CartonCompleted + @n_NoOfCarton
               END
            END
         END
         SET @n_CartonOnTrolley = @n_CartonOnTrolley + @n_CTNOnTrolley
         FETCH NEXT FROM CUR_CARTON INTO @n_Qty
                                       , @n_UCCQty
                                       , @c_Status
                                       , @c_FinalLoc
                                       , @c_PickLoc
                                       , @c_FromLocType
                                       , @c_ToLocType
                                       , @n_CTNOnTrolley
      END
      CLOSE CUR_CARTON
      DEALLOCATE CUR_CARTON

      IF @n_TotalCartonNo = 0 
      BEGIN
         DECLARE CUR_ALLOC_CARTON CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT Qty = SUM(PICKDETAIL.Qty)
               ,Storerkey = PICKDETAIL.Storerkey
               ,Sku = PICKDETAIL.Sku
               ,Loc = PICKDETAIL.Loc
         FROM WAVEDETAIL WITH (NOLOCK)
         JOIN PICKDETAIL WITH (NOLOCK) ON (WAVEDETAIL.Orderkey = PICKDETAIl.Orderkey)
         JOIN SKU        WITH (NOLOCK) ON (PICKDETAIL.Storerkey  = SKU.Storerkey)
                                       AND(PICKDETAIL.Sku = SKU.Sku)
         WHERE WAVEDETAIL.Wavekey = @c_Wavekey
         AND   SKU.BUSR5 = @c_Brand
         GROUP BY PICKDETAIL.Storerkey
               ,  PICKDETAIL.Sku
               ,  PICKDETAIL.Loc
   
         OPEN CUR_ALLOC_CARTON      
               
         FETCH NEXT FROM CUR_ALLOC_CARTON INTO @n_Qty 
                                             , @c_Storerkey
                                             , @c_Sku
                                             , @c_PickLoc


         WHILE @@FETCH_STATUS <> -1  
         BEGIN 
            SELECT TOP 1 @n_UCCQty = QTY
            FROM UCC WITH (NOLOCK)
            WHERE Storerkey = @c_Storerkey
            AND   Sku       = @c_Sku
            AND   Loc       = @c_PickLoc
 
            SET @n_UCCQty = CASE WHEN @n_UCCQty = 0 THEN 1 ELSE @n_UCCQty END

            SET @n_NoOfCarton = CEILING(@n_Qty / @n_UCCQty)

            SET @n_TotalCartonNo = @n_TotalCartonNo + @n_NoOfCarton

            FETCH NEXT FROM CUR_ALLOC_CARTON INTO @n_Qty
                                                , @c_Storerkey
                                                , @c_Sku
                                                , @c_PickLoc
         END
         CLOSE CUR_ALLOC_CARTON  
         DEALLOCATE CUR_ALLOC_CARTON  

      END

      SET @n_CartonOnInduction = @n_CartonOnInduction - @n_CartonOnTrolley - @n_CartonCompleted

      IF @n_TotalCartonNo > 0 AND @n_TotalCartonNo > @n_CartonCompleted 
      BEGIN
         SET @n_CompletedPctg = CONVERT(FLOAT, @n_CartonCompleted) / CONVERT(FLOAT, @n_TotalCartonNo) * 100

         SELECT TOP 1 @c_TrolleyNo = TLY.TrolleyNo
         FROM UCC WITH (NOLOCK) 
         JOIN SKU WITH (NOLOCK)                   ON (UCC.Storerkey = UCC.Sku)
         JOIN rdt.RDTTROLLEYLOG TLY WITH (NOLOCK) ON (UCC.UCCNo = TLY.UCCNo)
         JOIN TASKDETAIL        TD  WITH (NOLOCK) ON (TLY.Taskdetailkey = TD.TaskDetailKey)
         WHERE TD.Wavekey = @c_Wavekey
         AND   SKU.Busr5 = @c_brand
         ORDER BY TLY.Position

         SELECT @n_NoOfTrolleyUser = COUNT(DISTINCT ISNULL(RTRIM(MOB.UserName),''))
         FROM rdt.RDTMOBREC MOB WITH (NOLOCK) 
         WHERE MOB.V_String1 = @c_TrolleyNo
         AND MOB.Func IN (740, 741)
    
         INSERT INTO #TEMP_REPL 
         (  WaveKey
         ,  Brand
         ,  TotalCartonNo
         ,  CartonOnInduction
         ,  CartonOnTrolley
         ,  CartonCompleted
         ,  CompletedPctg
         ,  NoOfTrolleyUser
         ,  TotalQtyPiece
         ,  QtyPieceLeft
         ,  Short
         )
         VALUES
         (  @c_WaveKey
         ,  @c_Brand
         ,  @n_TotalCartonNo
         ,  @n_CartonOnInduction
         ,  @n_CartonOnTrolley
         ,  @n_CartonCompleted
         ,  @n_CompletedPctg
         ,  @n_NoOfTrolleyUser
         ,  @n_TotalQtyPiece
         ,  @n_QtyPieceLeft
         ,  @c_Short
         )
      END

      FETCH NEXT FROM CUR_REPL INTO @c_Wavekey
                                 ,  @c_Brand
                                 ,  @c_Short
   END
   CLOSE CUR_REPL
   DEALLOCATE CUR_REPL


   SELECT WaveKey
      ,  Brand
      ,  TotalCartonNo
      ,  CartonOnInduction
      ,  CartonOnTrolley
      ,  CartonCompleted
      ,  CompletedPctg
      ,  NoOfTrolleyUser
      ,  TotalQtyPiece
      ,  QtyPieceLeft
      ,  Short
   FROM #TEMP_REPL
   ORDER BY Wavekey
         ,  Brand
END

GO