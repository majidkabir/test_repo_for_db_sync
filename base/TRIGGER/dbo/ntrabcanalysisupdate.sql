SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Trigger: ntrABCAnalysisUpdate                                           */
/* Creation Date: 11-Jul-2013                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose:  Update other transactions while ABCAnalysis is updated        */
/*                                                                         */
/* Return Status:                                                          */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Called By: When records Update                                          */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Modifications:                                                          */
/* Date        Author   Ver   Purposes                                     */
/* 14-APR-2017 Wan01    1.0   WMS-1615 - CN&SG Logitech ABC function for   */
/*                            Cycle Count                                  */
/***************************************************************************/

CREATE TRIGGER ntrABCAnalysisUpdate ON ABCAnalysis
FOR UPDATE
AS
BEGIN
   IF @@ROWCOUNT = 0
   BEGIN
      RETURN
   END 

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue        INT                     
         , @n_StartTCnt       INT            -- Holds the current transaction count    
         , @b_Success         INT            -- Populated by calls to stored procedures - was the proc successful?    
         , @n_err             INT            -- Error number returned by stored procedure or this trigger    
         , @c_errmsg          NVARCHAR(255)  -- Error message returned by stored procedure or this trigger    

         , @n_SerialKey       INT
         , @c_ABCStatus       NVARCHAR(10)
         , @c_Storerkey       NVARCHAR(15)
         , @c_Sku             NVARCHAR(20)
         , @c_OldABC          NVARCHAR(10)
         , @c_CalcABC         NVARCHAR(10)
         , @c_NewABC          NVARCHAR(10)

         , @c_OldPieceABC     NVARCHAR(10)
         , @c_CalcPieceABC    NVARCHAR(10)
         , @c_NewPieceABC     NVARCHAR(10)

         , @c_OldCaseABC      NVARCHAR(10)
         , @c_CalcCaseABC     NVARCHAR(10)
         , @c_NewCaseABC      NVARCHAR(10)

         , @c_OldBulkABC      NVARCHAR(10)
         , @c_CalcBulkABC     NVARCHAR(10)
         , @c_NewBulkABC      NVARCHAR(10)
         , @c_ABCTranKey      NVARCHAR(10)
   
         , @n_ABCFinalized    INT

         , @c_UpdateCCDay     NVARCHAR(1) --(Wan01) 
         , @c_CCDay           NVARCHAR(10)--(Wan01) 
         , @n_CCDay           INT         --(Wan01)

   SET @n_Continue  = 1
   SET @n_StartTCnt = @@TRANCOUNT   
   
   SET @c_ABCStatus = '0'
   
   IF UPDATE(ArchiveCop)
   BEGIN
      SET @n_continue = 4 
      GOTO QUIT
   END

   IF NOT UPDATE(EditDate) 
   BEGIN
      UPDATE ABCANALYSIS WITH (ROWLOCK)
      SET EditWho = SUSER_SNAME()
         ,EditDate = GETDATE()
         ,TrafficCop = NULL
      FROM ABCANALYSIS
      JOIN INSERTED ON (ABCANALYSIS.Serialkey = INSERTED.Serialkey)

      SET @n_err = @@ERROR 
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(CHAR(250),@n_err)
         SET @n_err=63700   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table ABCANALYSIS. (ntrABCAnalysisUpdate)' 
                      + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO QUIT
      END
   END
   
   IF UPDATE(TrafficCop)
   BEGIN
      SET @n_Continue = 4
      GOTO QUIT
   END

   DECLARE CUR_ABC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT INSERTED.SerialKey
         ,INSERTED.Storerkey
         ,INSERTED.Sku

         ,SKU.ABC
         ,INSERTED.CalcABC
         ,INSERTED.NewABC

         ,SKU.ABCEA
         ,INSERTED.CalcPieceABC
         ,INSERTED.NewPieceABC

         ,SKU.ABCCS
         ,INSERTED.CalcCaseABC
         ,INSERTED.NewCaseABC

         ,SKU.ABCPL
         ,INSERTED.CalcBulkABC
         ,INSERTED.NewBulkABC

         ,ABCFinalized = CASE WHEN DELETED.FinalizedFlag = 'N' AND INSERTED.FinalizedFlag = 'Y' THEN 1 ELSE 0 END
   FROM INSERTED
   JOIN DELETED ON (INSERTED.SerialKey = DELETED.SerialKey)
   JOIN SKU WITH (NOLOCK) ON (INSERTED.Storerkey = SKU.Storerkey) AND (INSERTED.Sku = SKU.Sku)

   OPEN CUR_ABC
   FETCH NEXT FROM CUR_ABC INTO @n_SerialKey
                              , @c_Storerkey
                              , @c_Sku
                              , @c_OldABC  
                              , @c_CalcABC    
                              , @c_NewABC       
                              , @c_OldPieceABC 
                              , @c_CalcPieceABC 
                              , @c_NewPieceABC  
                              , @c_OldCaseABC  
                              , @c_CalcCaseABC
                              , @c_NewCaseABC   
                              , @c_OldBulkABC 
                              , @c_CalcBulkABC 
                              , @c_NewBulkABC  
                              , @n_ABCFinalized 

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      IF @c_NewABC      <> @c_OldABC OR @c_NewABC <> @c_CalcABC OR
         @c_NewPieceABC <> @c_OldPieceABC OR @c_NewPieceABC <> @c_CalcPieceABC OR
         @c_NewCaseABC  <> @c_OldCaseABC  OR @c_NewCaseABC  <> @c_CalcCaseABC OR
         @c_NewBulkABC  <> @c_OldBulkABC  OR @c_NewBulkABC  <> @c_CalcBulkABC  
      BEGIN
         SET @c_ABCStatus = '2'
      END

      UPDATE ABCANALYSIS WITH (ROWLOCK)
      SET SKUABCStatus = @c_ABCStatus
      WHERE SerialKey = @n_Serialkey
      AND   SKUABCStatus <> @c_ABCStatus

      SET @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63705   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table ABCANALYSIS. (ntrABCAnalysisUpdate)' 
         GOTO QUIT
      END 

      IF (  @c_OldABC <> @c_NewABC OR
            @c_OldPieceABC <> @c_NewPieceABC OR
            @c_OldCaseABC  <> @c_NewCaseABC OR
            @c_OldBulkABC  <> @c_NewBulkABC ) AND
            @n_ABCFinalized = 1
      BEGIN

         EXECUTE  nspg_getkey
         'ABCTranKey'
         , 10
         , @c_ABCTranKey   OUTPUT
         , @b_success      OUTPUT
         , @n_err          OUTPUT
         , @c_errmsg       OUTPUT

         IF NOT @b_success = 1
         BEGIN
            SET @n_continue = 3
            SET @n_err = 63702
            SET @c_errmsg = 'ntrABCAnalysisUpdate: ' + RTRIM(@c_errmsg)
            GOTO QUIT
         END

         INSERT ABCTRAN
         (  ABCTranKey
         ,  Facility
         ,  StorerKey
         ,  Sku
         ,  Status
         ,  OldABC
         ,  NewABC
         ,  CalcABC
         ,  SkuRank                 
         ,  NoOfPick                
         ,  PercentageOfPick        
         ,  AvgDailyPick            
         ,  ActivePickDays          
         ,  DaysOfActivity 
         ,  ABCEA          
         ,  NewPieceABC 
         ,  CalcPieceABC             
         ,  PieceRank               
         ,  NoOfPiecePick           
         ,  AvgDailyPiecePick       
         ,  PiecePickQty            
         ,  AvgDailyPiecePickQty    
         ,  NoOfPieceLoc            
         ,  PieceStdev              
         ,  PieceQtyLocMin          
         ,  PieceQtyLocMinInCS      
         ,  AvgPieceQtyLocLimit     
         ,  ABCCS                   
         ,  NewCaseABC   
         ,  CalcCaseABC            
         ,  CaseRank                
         ,  NoOfCasePick            
         ,  AvgDailyCasePick        
         ,  CasePickQty             
         ,  AvgDailyCasePickQty     
         ,  NoOfCaseLoc             
         ,  CaseStdev               
         ,  CaseQtyLocMin           
         ,  CaseQtyLocMininCS       
         ,  AvgCaseQtyLocLimit      
         ,  ABCPL                   
         ,  NewBulkABC  
         ,  CalcBulkABC            
         ,  BulkRank                
         ,  NoOfBulkPick            
         ,  AvgDailyBulkPick        
         ,  NoOfBulkLoc             
         )
         SELECT
            @c_ABCTranKey
         ,  INSERTED.Facility
         ,  INSERTED.Storerkey
         ,  INSERTED.Sku
         ,  @c_ABCStatus
         ,  @c_OldABC
         ,  @c_NewABC
         ,  @c_CalcABC
         ,  INSERTED.SkuRank                 
         ,  INSERTED.NoOfPick                
         ,  INSERTED.PercentageOfPick        
         ,  INSERTED.AvgDailyPick            
         ,  INSERTED.ActivePickDays          
         ,  INSERTED.DaysOfActivity          
         ,  @c_OldPieceABC
         ,  @c_NewPieceABC
         ,  @c_CalcPieceABC          
         ,  INSERTED.PieceRank               
         ,  INSERTED.NoOfPiecePick           
         ,  INSERTED.AvgDailyPiecePick       
         ,  INSERTED.PiecePickQty            
         ,  INSERTED.AvgDailyPiecePickQty    
         ,  INSERTED.NoOfPieceLoc            
         ,  INSERTED.PieceStdev              
         ,  INSERTED.PieceQtyLocMin          
         ,  INSERTED.PieceQtyLocMinInCS      
         ,  INSERTED.AvgPieceQtyLocLimit     
         ,  @c_OldCaseABC
         ,  @c_NewCaseABC
         ,  @c_CalcCaseABC             
         ,  INSERTED.CaseRank                
         ,  INSERTED.NoOfCasePick            
         ,  INSERTED.AvgDailyCasePick        
         ,  INSERTED.CasePickQty             
         ,  INSERTED.AvgDailyCasePickQty     
         ,  INSERTED.NoOfCaseLoc             
         ,  INSERTED.CaseStdev               
         ,  INSERTED.CaseQtyLocMin           
         ,  INSERTED.CaseQtyLocMininCS       
         ,  INSERTED.AvgCaseQtyLocLimit      
         ,  @c_OldBulkABC                   
         ,  @c_NewBulkABC
         ,  @c_CalcBulkABC              
         ,  INSERTED.BulkRank                
         ,  INSERTED.NoOfBulkPick            
         ,  INSERTED.AvgDailyBulkPick        
         ,  INSERTED.NoOfBulkLoc             
         FROM INSERTED
         WHERE SerialKey = @n_SerialKey

         SET @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
            SET @n_continue= 3
            SET @n_err     = 63703   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': INSERT table ABCItrn faail. (ntrABCAnalysisUpdate)' 
            GOTO QUIT
         END 

         --(Wan01) - START
         SET @c_UpdateCCDay = ''
         SELECT @c_UpdateCCDay = UpdateCCDay
         FROM STORER WITH (NOLOCK)
         WHERE Storerkey = @c_Storerkey

         IF @c_UpdateCCDay = 'Y'
         BEGIN
            SET @n_CCDay = 0
            SELECT @c_CCDay = ISNULL(RTRIM(Short),'')
            FROM CODELKUP WITH (NOLOCK)
            WHERE ListName = 'ABCUPDCC'
            AND Storerkey = @c_Storerkey
            AND Code = @c_NewABC

            IF ISNUMERIC(@c_CCDay) = 0
            BEGIN
               SET @n_continue= 3
               SET @n_err     = 63710   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Invalid CC Day Setup in Codelkup. (ntrABCAnalysisUpdate)' 
               GOTO QUIT
            END

            SET @n_CCDay = CONVERT(INT, @c_CCDay)
         END

         UPDATE SKU WITH (ROWLOCK)
         SET ABC   = @c_NewABC
            ,ABCEA = @c_NewPieceABC 
            ,ABCCS = @c_NewCaseABC
            ,ABCPL = @c_NewBulkABC
            ,CycleCountFrequency = CASE WHEN @c_UpdateCCDay = 'Y' THEN @n_CCDay ELSE CycleCountFrequency END
         WHERE Storerkey = @c_Storerkey
         AND   Sku = @c_Sku
         --(Wan01) - END

         SET @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
            SET @n_continue= 3
            SET @n_err     = 63704   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table SKU. (ntrABCAnalysisUpdate)' 
            GOTO QUIT
         END 
      END

      FETCH NEXT FROM CUR_ABC INTO @n_SerialKey
                                 , @c_Storerkey
                                 , @c_Sku
                                 , @c_OldABC  
                                 , @c_CalcABC    
                                 , @c_NewABC       
                                 , @c_OldPieceABC 
                                 , @c_CalcPieceABC 
                                 , @c_NewPieceABC  
                                 , @c_OldCaseABC  
                                 , @c_CalcCaseABC
                                 , @c_NewCaseABC   
                                 , @c_OldBulkABC 
                                 , @c_CalcBulkABC 
                                 , @c_NewBulkABC  
                                 , @n_ABCFinalized
   END
   CLOSE CUR_ABC
   DEALLOCATE CUR_ABC
QUIT:
   --(Wan01) - START
   IF CURSOR_STATUS( 'LOCAL', 'CUR_ABC') in (0 , 1)  
   BEGIN
      CLOSE CUR_ABC
      DEALLOCATE CUR_ABC
   END
   --(Wan01) - END

   /* #INCLUDE <TRRDA2.SQL> */    
   IF @n_Continue=3  -- Error Occured - Process And Return    
   BEGIN    
      IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt    
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

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrABCAnalysisUpdate'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR 

      RETURN    
   END    
   ELSE    
   BEGIN    
      WHILE @@TRANCOUNT > @n_starttcnt    
      BEGIN    
         COMMIT TRAN    
      END    

      RETURN    
   END      
END

GO