SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_WOMBuildJob_Wrapper                             */  
/* Creation Date: 27-SEP-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-466 - Inventory Work Order Management  Work Order       */
/*        : Execution  Job Maintenance                                   */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */ 
/* 2021-02-10   mingle01 1.1  Add Big Outer Begin try/Catch              */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/*************************************************************************/   
CREATE PROCEDURE [WM].[lsp_WOMBuildJob_Wrapper]  
   @c_WorkOrderKeyList     NVARCHAR(4000)
,  @c_JobKey               NVARCHAR(10) = '' OUTPUT
,  @b_Success              INT          = 1  OUTPUT   
,  @n_Err                  INT          = 0  OUTPUT
,  @c_Errmsg               NVARCHAR(250)= '' OUTPUT
,  @c_UserName             NVARCHAR(128)= ''
,  @n_ErrGroupKey          INT = 0           OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue        INT = 1
         , @n_StartTCnt       INT = @@TRANCOUNT

   DECLARE @n_InValidWorkOrder      INT = 0           
         , @n_MasterWorkOrderCnt    INT = 0           
         , @n_FacilityCnt           INT = 0           
         , @n_StorerkeyCnt          INT = 0 
         , @n_WorkOrderTypeCnt      INT = 0          
                                                      
   DECLARE @c_Facility              NVARCHAR(5) = ''  
         , @c_Storerkey             NVARCHAR(15) = '' 
         , @c_WorkOrderKey          NVARCHAR(10) = '' 
         , @c_MasterWorkOrder       NVARCHAR(50) = '' 
         , @c_WorkOrderName         NVARCHAR(50) = '' 
         , @c_ExternalReference     NVARCHAR(30) = '' 
         , @c_Priority              NVARCHAR(10) = '' 
         , @c_Descr                 NVARCHAR(60) = '' 
         , @c_WorkStation           NVARCHAR(10) = '' 
         , @n_UOMQty                INT = 0           
         , @n_UOMQtyRemaining       INT = 0           
         , @c_WOStatus              NVARCHAR(10) = '' 
         , @dt_StartDate            DATETIME          
         , @dt_DueDate              DATETIME 
          
         , @n_JobUOMQty             INT          = 0   
         , @n_EstJobDuration        INT          = 0
         , @c_JobPriority           NVARCHAR(10) = ''
 
         , @n_SeqNo                 INT          = 0
         , @n_NoOfAssignedWorker    INT          = 0 
         , @n_STDTime               INT          = 0.00
         , @n_EstMins               INT          = 0
         , @c_TimeRate              NVARCHAR(30) = '' 

         , @CUR_WOR                 CURSOR

   SET @b_Success = 1
   SET @c_ErrMsg = ''

   CREATE TABLE #TMP_WOR
   (  WorkOrderKey     NVARCHAR(10)  NOT NULL
   )


   SET @n_Err = 0 
   --(mingle01) - START   
   IF SUSER_SNAME() <> @c_UserName
   BEGIN
      EXEC [WM].[lsp_SetUser] 
            @c_UserName = @c_UserName  OUTPUT
         ,  @n_Err      = @n_Err       OUTPUT
         ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
                
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END
    
      EXECUTE AS LOGIN = @c_UserName
   END
   --(mingle01) - END
   
   --(mingle01) - START
   BEGIN TRY

      INSERT INTO #TMP_WOR ( WorkOrderKey )
      SELECT   WorkOrderKey   = ISNULL(RTRIM(WOK.ColValue),'')
      FROM dbo.fnc_DelimSplit ('|', @c_WorkOrderKeyList)  WOK
      

      SET @n_InValidWorkOrder  = 0
      SET @n_MasterWorkOrderCnt= 0
      SET @n_FacilityCnt       = 0
      SET @n_StorerkeyCnt      = 0
      SELECT @n_InValidWorkOrder   = ISNULL(SUM(CASE WHEN NOT (WOR.WOStatus < '9' AND WOR.UOMQtyRemaining > 0) THEN 1 ELSE 0 END),0)
            ,@n_MasterWorkOrderCnt = COUNT(DISTINCT WOR.MasterWorkOrder)
            ,@n_FacilityCnt        = COUNT(DISTINCT WOR.Facility)
            ,@n_StorerkeyCnt       = COUNT(DISTINCT WOR.Storerkey)
            ,@n_WorkOrderTypeCnt   = COUNT(DISTINCT WO.WorkOrderType)
      FROM #TMP_WOR TMP
      JOIN WORKORDERREQUEST WOR WITH (NOLOCK) ON ( TMP.WorkOrderKey = WOR.WorkOrderKey )
      JOIN WORKORDERROUTING WO  WITH (NOLOCK) ON ( WOR.MasterWorkOrder = WO.MasterWorkOrder )
                                              AND( WOR.WorkOrderName = WO.WorkOrderName )

      IF @n_InValidWorkOrder > 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 550501
         SET @c_ErrMsg = 'NSQL' + CONVERT( CHAR(6), @n_err) + ': Closed/Completed Work Order is not eligible generate job.'
                        +'. (lsp_WOMBuildJob_Wrapper)'
         GOTO EXIT_SP
      END

      IF @n_MasterWorkOrderCnt > 1 OR @n_FacilityCnt > 1 OR @n_StorerkeyCnt > 1 
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 550502
         SET @c_ErrMsg = 'NSQL' + CONVERT( CHAR(6), @n_err) + ': Different Master Work Order/Facility/Storer cannot be combined to build job.'
                        +'. (lsp_WOMBuildJob_Wrapper)'
         GOTO EXIT_SP
      END

      SET @CUR_WOR = CURSOR  FAST_FORWARD READ_ONLY FOR
      SELECT   WOR.Facility
            ,  WOR.Storerkey
            ,  WOR.WorkOrderKey
            ,  WOR.MasterWorkOrder  
            ,  WOR.WorkOrderName  
            ,  WOR.[Priority]
            ,  WOR.WorkStation
            ,  WOR.UOMQty
            ,  WOR.UOMQtyRemaining
            ,  WOR.WOStatus
            ,  WOR.StartDate
            ,  WOR.DueDate 
      FROM #TMP_WOR TMP
      JOIN WORKORDERREQUEST WOR WITH (NOLOCK) ON ( TMP.WorkOrderKey = WOR.WorkOrderKey )
      ORDER BY WOR.[Priority]
            ,  WOR.DueDate
            ,  WOR.WorkOrderkey

      OPEN @CUR_WOR
      
      FETCH NEXT FROM @CUR_WOR INTO   @c_Facility             
                                    ,  @c_Storerkey            
                                    ,  @c_WorkOrderKey           
                                    ,  @c_MasterWorkOrder      
                                    ,  @c_WorkOrderName        
                                    ,  @c_Priority             
                                    ,  @c_WorkStation          
                                    ,  @n_UOMQty               
                                    ,  @n_UOMQtyRemaining      
                                    ,  @c_WOStatus             
                                    ,  @dt_StartDate           
                                    ,  @dt_DueDate             
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @n_SeqNo = @n_SeqNo + 1 
    
         IF @c_JobKey = ''
         BEGIN
            SET @b_success = 1  
            BEGIN TRY      
               EXECUTE nspg_getkey        
               'JobKey'        
               , 10        
               , @c_JobKey   OUTPUT        
               , @b_success         OUTPUT        
               , @n_err             OUTPUT        
               , @c_errmsg          OUTPUT        
            END TRY

            BEGIN CATCH
               SET @n_err = 550503
               SET @c_ErrMsg = ERROR_MESSAGE()
               SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) 
                             + ': Error Executing nspg_getkey - JobKey. (lsp_WOMBuildJob_Wrapper)'
                             + '( ' + @c_errmsg + ' )'
            END CATCH 

            IF @b_success = 0 OR @n_Err <> 0        
            BEGIN        
               SET @n_continue = 3      
               GOTO EXIT_SP
            END  

            BEGIN TRY
               INSERT INTO WORKORDERJOBDETAIL 
                  (  JobKey
                  ,  Facility
                  ,  Storerkey
                  ,  MasterWorkOrder
                  ,  JobStatus
                  ,  [Priority]
                  ,  EstJobStartTime
                  ,  QAType
                  ,  QAValue
                  ,  QALocation
                  ,  WORelease
                  )
               SELECT TOP 1
                     @c_JobKey
                  ,  @c_Facility
                  ,  @c_Storerkey
                  ,  @c_MasterWorkOrder
                  ,  '0'
                  ,  @c_Priority
                  ,  GETDATE()
                  ,  QAType
                  ,  QAValue
                  ,  QALocation
                  ,  WORelease = CASE WHEN @n_WorkOrderTypeCnt > 1 THEN WorkOrderRelease ELSE 'Full Release' END
               FROM WORKORDERROUTING WITH (NOLOCK)
               WHERE MasterWorkOrder = @c_MasterWorkOrder
               AND   WorkOrderName = @c_WorkOrderName

            END TRY

            BEGIN CATCH
               SET @n_err = 550504
               SET @c_ErrMsg = ERROR_MESSAGE()
               SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) 
                             + ': Insert Into WORKORDERJOBDETAIL Fail. (lsp_WOMBuildJob_Wrapper)'
                             + '( ' + @c_errmsg + ' )'
            END CATCH    

            IF @b_success = 0 OR @n_Err <> 0        
            BEGIN        
               SET @n_continue = 3      
               GOTO EXIT_SP
            END 
         END

         SET @n_NoOfAssignedWorker = 0
      
         SELECT @n_NoOfAssignedWorker = ISNULL(NoOfAssignedWorker,0)
         FROM WORKSTATION WITH (NOLOCK)
         WHERE Facility = @c_Facility 
         AND   WorkStation = @c_WorkStation

         SET @n_STDTime = 0.00
         SET @c_TimeRate= ''        
         SELECT @n_STDTime = ISNULL(WOS.STDTime,  0.00)    
               ,@c_TimeRate= ISNULL(RTRIM(WOS.TimeRate), '')
         FROM WORKORDERSTEPS WOS WITH (NOLOCK)
         WHERE WOS.MasterWorkOrder = @c_MasterWorkOrder
         AND   WOS.WorkOrderName   = @c_WorkOrderName
         AND   WOS.WOOperation = 'BEGIN FG'

         SET @n_EstMins = 0
         IF @c_TimeRate = 'flat rate'
         BEGIN
            SET @n_EstMins = CEILING(@n_STDTime * (@n_UOMQtyRemaining * 1.00))
         END
         
         IF @c_TimeRate = 'rate per worker'
         BEGIN
            IF @n_NoOfAssignedWorker > 0 
            BEGIN
               SET @n_EstMins = CEILING((@n_STDTime / @n_NoOfAssignedWorker) *  (@n_UOMQtyRemaining * 1.00))
            END
         END   

         BEGIN TRY
            INSERT INTO WORKORDERJOB 
            (  JobKey
            ,  Facility
            ,  Storerkey
            ,  WorkOrderKey
            ,  WorkOrderName
            ,  [Sequence]
            ,  WorkStation
            ,  TimeRate
            ,  NoOfAssignedWorker
            ,  STDTime 
            ,  EstMins
            ,  UOMQtyJob
            ,  JobStatus
            )
            VALUES
            (  @c_JobKey
            ,  @c_Facility
            ,  @c_Storerkey
            ,  @c_WorkOrderKey
            ,  @c_WorkOrderName
            ,  @n_SeqNo
            ,  @c_WorkStation
            ,  @c_TimeRate
            ,  @n_NoOfAssignedWorker
            ,  @n_STDTime 
            ,  @n_EstMins
            ,  @n_UOMQtyRemaining 
            ,  '0'
            )

         END TRY

         BEGIN CATCH
            SET @n_err = 550505
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) 
                          + ': Insert Into WORKORDERJOB Fail. (lsp_WOMBuildJob_Wrapper)'
                          + '( ' + @c_errmsg + ' )'
         END CATCH    

         IF @b_success = 0 OR @n_Err <> 0        
         BEGIN        
            SET @n_continue = 3      
            GOTO EXIT_SP
         END 

         SET @n_EstJobDuration = @n_EstJobDuration + @n_EstMins
         SET @n_JobUOMQty = @n_JobUOMQty + @n_UOMQtyRemaining

         FETCH NEXT FROM @CUR_WOR INTO    @c_Facility             
                                       ,  @c_Storerkey            
                                       ,  @c_WorkOrderKey           
                                       ,  @c_MasterWorkOrder      
                                       ,  @c_WorkOrderName        
                                       ,  @c_Priority             
                                       ,  @c_WorkStation          
                                       ,  @n_UOMQty               
                                       ,  @n_UOMQtyRemaining      
                                       ,  @c_WOStatus             
                                       ,  @dt_StartDate           
                                       ,  @dt_DueDate   
      END
      CLOSE @CUR_WOR 
      DEALLOCATE @CUR_WOR

      IF @c_JobKey <> '' AND (@n_EstJobDuration + @n_JobUOMQty) > 0
      BEGIN
         BEGIN TRY
            UPDATE WORKORDERJOBDETAIL 
               SET  UOMQtyJob = @n_JobUOMQty
                  , EstJobDuration = @n_EstJobDuration
                  , EstCompletionTime    =  DATEADD(Minute, @n_EstJobDuration, EstJobStartTime)
                  , ActualCompletionTime =  DATEADD(Minute, @n_EstJobDuration, EstJobStartTime)
                  , ArchiveCop = NULL
            WHERE JobKey = @c_JobKey
         END TRY

         BEGIN CATCH
            SET @n_err = 550506
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) 
                          + ': Update Into WORKORDERJOBDETAIL Fail. (lsp_WOMBuildJob_Wrapper)'
                          + '( ' + @c_errmsg + ' )'
         END CATCH    

         IF @b_success = 0 OR @n_Err <> 0        
         BEGIN        
            SET @n_continue = 3      
            GOTO EXIT_SP
         END 
      END
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END    
   EXIT_SP:
   DROP TABLE #TMP_WOR   

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_WOMBuildJob_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
   
   REVERT      
END

GO