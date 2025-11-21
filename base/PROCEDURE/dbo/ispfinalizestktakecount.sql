SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Stored Proc : ispFinalizeStkTakeCount                                   */  
/* Creation Date:                                                          */  
/* Copyright: IDS                                                          */  
/* Written by:                                                             */  
/*                                                                         */  
/* Purpose:                                                                */  
/*                                                                         */  
/*                                                                         */  
/* Usage:                                                                  */  
/*                                                                         */  
/* Local Variables:                                                        */  
/*                                                                         */  
/* Called By:                                                              */  
/*                                                                         */  
/* PVCS Version: 1.2                                                       */  
/*                                                                         */  
/* Version: 5.4                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date        Author  Ver   Purposes                                      */  
/* 06/06/2015  NJOW01  1.0   349528 - CC Finalize update last cc date      */
/* 09/07/2020  NJOW02  1.1   WMS-13685 CC Finalize Extended validation     */
/* 12/11/2021  Wan01   1.2   DevOps Combine Script.                        */
/* 12/11/2021  Wan01   1.2   WMS-18332 - [TW]LOR_CycleCount_CR             */
/* 19/10/2022  NJOW03  1.3   WMS-20991 TH Finalize stocktake by count sheet*/
/* 19/10/2022  NJOW03  1.3   DEVOPS Combine script                         */
/***************************************************************************/  

CREATE PROCEDURE [dbo].[ispFinalizeStkTakeCount]
   @c_StockTakeKey NVARCHAR(10), 
   @n_CountNo int,
   @c_CountSheets NVARCHAR(MAX) = ''  --NJOW03
AS
    SET NOCOUNT ON   
    SET ANSI_NULLS OFF
    SET QUOTED_IDENTIFIER OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_Continue int

   SELECT @n_Continue = 1
   
   --NJOW01 Start
   DECLARE @c_SQL                           NVARCHAR(1000),
           @c_Facility                      NVARCHAR(5),
           @c_StorerParm                    NVARCHAR(60),
           @c_Storer_SCSQL                  NVARCHAR(800), 
           @c_Storer_SCSQL2                 NVARCHAR(800),
           @b_success                       INT,
           @c_ErrMsg                        NVARCHAR(250),
           @n_err                           INT,
           @c_CCFinalizeUpdLastCntDate      NVARCHAR(10),
           @c_CCValidationRules             NVARCHAR(30), --NJOW02
           @c_StockTakeFinalizeByCountSheet NVARCHAR(30), --NJOW03
           @c_AllCSheetFinalized            NVARCHAR(5)   --NJOW03 
  
   SET @c_AllCSheetFinalized = 'Y'  --NJOW03
  
   CREATE TABLE #STORER_CONFIG 
   (
         StorerKey  NVARChar (15) NULL ,
         Configkey  NVARChar (30) NULL ,
         SValue     NVARChar (10) NULL 
   )
   
   SELECT @c_Facility = Facility,
          @c_StorerParm = StorerKey
   FROM STOCKTAKESHEETPARAMETERS (NOLOCK)
   WHERE StockTakeKey = @c_StockTakeKey
   
   EXEC ispParseParameters
       @c_StorerParm,
       'string',
       'STORER.StorerKey',
       @c_Storer_SCSQL OUTPUT,
       @c_Storer_SCSQL2 OUTPUT,
       @b_success OUTPUT   
   
   SELECT @c_SQL = N'SELECT STORER.Storerkey, STORERCONFIG.Configkey, STORERCONFIG.Svalue '
         +  'FROM STORER (NOLOCK) '
         +  'LEFT JOIN STORERCONFIG (NOLOCK) ON STORER.Storerkey = STORERCONFIG.Storerkey AND (STORERCONFIG.Svalue=''1'' OR LEN(STORERCONFIG.Svalue) >= 5) '
         +  '                                AND (ISNULL(STORERCONFIG.Facility,'''')='''' OR STORERCONFIG.Facility = ''' + ISNULL(RTRIM(@c_facility), '') + ''') '
         +  'WHERE 1=1 '
         +  ISNULL(RTRIM(@c_Storer_SCSQL), '') + ' ' + ISNULL(RTRIM(@c_Storer_SCSQL2), '') + ' '
   
   INSERT INTO #STORER_CONFIG (StorerKey, Configkey, Svalue)
     EXEC (@c_SQL )         
         
   IF ((SELECT COUNT(DISTINCT Storerkey) FROM #STORER_CONFIG WHERE Configkey = 'CCFinalizeUpdLastCntDate' AND ISNULL(Svalue,'')='1') =      
      (SELECT COUNT(DISTINCT Storerkey) FROM #STORER_CONFIG)) AND 
      (SELECT COUNT(DISTINCT Storerkey) FROM #STORER_CONFIG WHERE Configkey = 'CCFinalizeUpdLastCntDate' AND ISNULL(Svalue,'')='1') > 0
   BEGIN
        SELECT @c_CCFinalizeUpdLastCntDate = '1'
   END
   ELSE
   BEGIN
        SELECT @c_CCFinalizeUpdLastCntDate = '0'
   END                          
   --NJOW01 End
   
   --NJOW03 S   
    IF ((SELECT COUNT(DISTINCT Storerkey) FROM #STORER_CONFIG WHERE Configkey = 'StockTakeFinalizeByCountSheet' AND ISNULL(Svalue,'')='1') =      
      (SELECT COUNT(DISTINCT Storerkey) FROM #STORER_CONFIG)) AND 
      (SELECT COUNT(DISTINCT Storerkey) FROM #STORER_CONFIG WHERE Configkey = 'StockTakeFinalizeByCountSheet' AND ISNULL(Svalue,'')='1') > 0
   BEGIN
        SELECT @c_StockTakeFinalizeByCountSheet = '1'
   END
   ELSE
   BEGIN
        SELECT @c_StockTakeFinalizeByCountSheet = '0'
   END  
   --NJOW03 E                           
      
   --NJOW02 S
   IF @n_continue IN(1,2)
   BEGIN          
        SELECT TOP 1 @c_CCValidationRules = SC.sValue  
        FROM   #STORER_CONFIG SC(NOLOCK)  
               JOIN CODELKUP CL(NOLOCK)  
                    ON  SC.sValue = CL.Listname  
        WHERE SC.Configkey = 'StockTakeExtendedValidation'  
                  
        IF ISNULL(@c_CCValidationRules ,'')<>''  
        BEGIN  
            EXEC isp_StockTake_ExtendedValidation @cStockTakeKey=@c_StockTakeKey  
                ,@nCountNo=@n_CountNo
                ,@cCCValidationRules=@c_CCValidationRules  
                ,@nSuccess=@b_Success OUTPUT  
                ,@cErrorMsg=@c_ErrMsg OUTPUT  
            
            IF @b_Success<>1  
            BEGIN  
                SELECT @n_Continue = 3  
                --SELECT @n_err = 72810  
            END  
        END  
        ELSE  
        BEGIN  
            SELECT TOP 1 @c_CCValidationRules = SC.sValue  
            FROM   #STORER_CONFIG SC(NOLOCK)  
            WHERE  SC.Configkey = 'StockTakeExtendedValidation'      
              
            IF EXISTS (  
                   SELECT 1  
                   FROM   dbo.sysobjects  
                   WHERE  NAME = RTRIM(@c_CCValidationRules)  
                   AND TYPE = 'P'  
               )  
            BEGIN  
                SET @c_SQL = 'EXEC '+@c_CCValidationRules+  
                    ' @c_StockTakeKey, @n_CountNo INT, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '  
                  
                EXEC sp_executesql @c_SQL  
                    ,  
                     N'@c_StockTakeKey NVARCHAR(10), @n_CountNo INT, @b_Success Int OUTPUT, @n_Err Int OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT'  
                    ,@c_StockTakekey
                    ,@n_CountNo  
                    ,@b_Success OUTPUT  
                    ,@n_Err OUTPUT  
                    ,@c_ErrMsg OUTPUT  
                  
                IF @b_Success<>1  
                BEGIN  
                    SELECT @n_Continue = 3      
                    --SELECT @n_err = 72811  
                END  
            END  
        END  
        
        IF @n_continue = 3
        BEGIN 
           RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR 
           RETURN
          END 
    END --    IF @n_Continue = 1 OR @n_Continue = 2  
    --NJOW02 E
   
   IF @n_continue IN(1,2)
   BEGIN
      IF @n_CountNo = 1 
      BEGIN
         BEGIN TRAN
         
         IF @c_StockTakeFinalizeByCountSheet = '1'  --NJOW03
         BEGIN
            UPDATE CCDETAIL
               SET FinalizeFlag = 'Y'
            WHERE CCKEY = @c_StockTakeKey
            AND CCSheetNo IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_CountSheets))
            
            IF EXISTS(SELECT 1 FROM CCDETAIL (NOLOCK) 
                      WHERE CCKEY = @c_StockTakeKey
                      AND FinalizeFlag <> 'Y')
            BEGIN              
               SET @c_AllCSheetFinalized = 'N'
            END
         END
         ELSE
         BEGIN
            UPDATE CCDETAIL
               SET FinalizeFlag = 'Y'
            WHERE CCKEY = @c_StockTakeKey
         END
         IF @@ERROR <> 0
         BEGIN
            SELECT @n_continue = 3
            RAISERROR ('Error Found Finalize Stock Take ispFinalizeStkTakeCount.', 16, 1)
            ROLLBACK TRAN
            RETURN
         END
         ELSE
           COMMIT TRAN
      END
      ELSE IF @n_CountNo = 2 
      BEGIN
         BEGIN TRAN

         IF @c_StockTakeFinalizeByCountSheet = '1'  --NJOW03
         BEGIN
            IF EXISTS(SELECT 1 FROM CCDETAIL (NOLOCK)
                      WHERE CCKEY = @c_StockTakeKey  
                      AND CCSheetNo IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_CountSheets))
                      AND FinalizeFlag <> 'Y')  
            BEGIN
               SELECT @n_continue = 3
               RAISERROR ('Not allow Finalize Count 2. Found some previous count is not finalized Yet. ispFinalizeStkTakeCount.', 16, 1)
               RETURN            	
            END                  	         	  
         	  
            UPDATE CCDETAIL
               SET FinalizeFlag_Cnt2 = 'Y'
            WHERE CCKEY = @c_StockTakeKey
            AND CCSheetNo IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_CountSheets))
            
            IF EXISTS(SELECT 1 FROM CCDETAIL (NOLOCK) 
                      WHERE CCKEY = @c_StockTakeKey
                      AND FinalizeFlag_Cnt2 <> 'Y')
            BEGIN              
               SET @c_AllCSheetFinalized = 'N'
            END            
         END
         ELSE
         BEGIN
            UPDATE CCDETAIL
               SET FinalizeFlag_Cnt2 = 'Y'
            WHERE CCKEY = @c_StockTakeKey
         END
         IF @@ERROR <> 0
         BEGIN
            SELECT @n_continue = 3
            RAISERROR ('Error Found Finalize Stock Take ispFinalizeStkTakeCount.', 16, 1)
            ROLLBACK TRAN
            RETURN
         END
         ELSE
           COMMIT TRAN
      END IF @n_CountNo = 3 
      BEGIN
         BEGIN TRAN
      
         IF @c_StockTakeFinalizeByCountSheet = '1'  --NJOW03
         BEGIN
            IF EXISTS(SELECT 1 FROM CCDETAIL (NOLOCK)
                      WHERE CCKEY = @c_StockTakeKey  
                      AND CCSheetNo IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_CountSheets))
                      AND (FinalizeFlag <> 'Y' OR FinalizeFlag_Cnt2 <> 'Y'))  
            BEGIN
               SELECT @n_continue = 3
               RAISERROR ('Not allow Finalize Count 3. Found some previous count is not finalized Yet. ispFinalizeStkTakeCount.', 16, 1)
               RETURN            	
            END                  	         	  
         	
            UPDATE CCDETAIL
               SET FinalizeFlag_Cnt3 = 'Y'
            WHERE CCKEY = @c_StockTakeKey
            AND CCSheetNo IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_CountSheets))
            
            IF EXISTS(SELECT 1 FROM CCDETAIL (NOLOCK) 
                      WHERE CCKEY = @c_StockTakeKey
                      AND FinalizeFlag_Cnt3 <> 'Y')
            BEGIN              
               SET @c_AllCSheetFinalized = 'N'
            END                        
         END
         ELSE
         BEGIN
            UPDATE CCDETAIL
               SET FinalizeFlag_Cnt3 = 'Y'
            WHERE CCKEY = @c_StockTakeKey
         END
         IF @@ERROR <> 0
         BEGIN
            SELECT @n_continue = 3
            RAISERROR ('Error Found Finalize Stock Take ispFinalizeStkTakeCount.', 16, 1)
            ROLLBACK TRAN
            RETURN
         END
         ELSE
           COMMIT TRAN
      END
   END

   IF (@n_continue = 1 OR @n_continue = 2) 
      AND @c_AllCSheetFinalized = 'Y'  --NJOW03
   BEGIN
      BEGIN TRAN

      UPDATE StockTakeSheetParameters
         SET FinalizeStage = @n_CountNo
      WHERE StockTakeKey = @c_StockTakeKey
      IF @@ERROR <> 0
      BEGIN
         SELECT @n_continue = 3
         RAISERROR ('Error Found when updaing StockTakeSheetParameters.', 16, 1)
         ROLLBACK TRAN
         RETURN
      END
      ELSE
        COMMIT TRAN
   END
   
   --NJOW01
   IF (@n_continue = 1 OR @n_continue = 2) AND @c_CCFinalizeUpdLastCntDate = '1' AND @n_CountNo IN(1,2,3)
   BEGIN
      BEGIN TRAN       
      	
        UPDATE SKU WITH (ROWLOCK)
        SET SKU.LastCycleCount = GETDATE()
        FROM CCDETAIL (NOLOCK) 
        JOIN SKU ON CCDETAIL.Storerkey = SKU.Storerkey AND CCDETAIL.Sku = SKU.Sku
        WHERE CCDETAIL.CCKey = @c_StockTakeKey
        AND (CCDETAIL.CCSheetNo IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_CountSheets))  --NJOW03
            OR @c_StockTakeFinalizeByCountSheet <> '1') 
        
        IF @@ERROR <> 0
        BEGIN
           SELECT @n_continue = 3
         RAISERROR ('Error Found when updaing StockTakeSheetParameters.', 16, 1)
           ROLLBACK TRAN
           RETURN
        END
        ELSE
        BEGIN
          UPDATE LOC WITH (ROWLOCK)
          SET LOC.LastCycleCount = GETDATE()
          FROM CCDETAIL (NOLOCK) 
          JOIN LOC ON CCDETAIL.Loc = LOC.Loc
          WHERE CCDETAIL.CCKey = @c_StockTakeKey
          AND (CCDETAIL.CCSheetNo IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_CountSheets))  --NJOW03
              OR @c_StockTakeFinalizeByCountSheet <> '1') 
          
          IF @@ERROR <> 0
          BEGIN
             SELECT @n_continue = 3
            RAISERROR ('Error Found when updaing StockTakeSheetParameters.', 16, 1)
             ROLLBACK TRAN
             RETURN
          END
          ELSE
            COMMIT TRAN
        END        
   END
   
   --(Wan01) - START
   IF @n_Continue IN ( 1, 2)
   BEGIN
      EXEC ispPostFinalizeStkTakeCount_Wrapper
         @c_StockTakeKey= @c_StockTakeKey
      ,  @n_CountNo = @n_CountNo       
   END
   --(Wan01) - END

GO