SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_TMCCReleaseFNZ_Wrapper                          */  
/* Creation Date: 19-OCT-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-1273 - Stored Procedures for Feature ¿C Release Cycle    */
/*          Count                                                        */  
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
CREATE PROCEDURE [WM].[lsp_TMCCReleaseFNZ_Wrapper]
   @c_BatchNo              NVARCHAR(10)  
,  @b_Success              INT          = 1   OUTPUT   
,  @n_Err                  INT          = 0   OUTPUT
,  @c_Errmsg               NVARCHAR(255)= ''  OUTPUT
,  @c_UserName             NVARCHAR(128)= ''
AS  
BEGIN  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue              INT = 1
         , @n_StartTCnt             INT = @@TRANCOUNT

         , @n_RowId                 BIGINT = 0
         , @c_CCKey                 NVARCHAR(10) = ''
         , @c_TaskDetailKey         NVARCHAR(10) = ''

         , @CUR_INSTASK             CURSOR

   SET @b_Success = 1
   SET @c_ErrMsg = ''

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
      SET @b_success = 1  
      BEGIN TRY      
         EXECUTE nspg_getkey        
         'CCKey'        
         , 10        
         , @c_CCKey     OUTPUT        
         , @b_success   OUTPUT        
         , @n_err       OUTPUT        
         , @c_errmsg    OUTPUT        
      END TRY

      BEGIN CATCH
         SET @n_err = 554701
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) 
                        + ': Error Executing nspg_getkey - CCKey. (lsp_TMCCReleaseFNZ_Wrapper)'
                        + '( ' + @c_errmsg + ' )'
      END CATCH    
                         
      IF @b_success = 0 OR @n_Err <> 0        
      BEGIN        
         SET @n_continue = 3      
         GOTO EXIT_SP
      END  

      SET @CUR_INSTASK = CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT RowID
      FROM TASKDETAIL_WIP WITH (NOLOCK)
      WHERE TaskWIPBatchNo = @c_BatchNo
      ORDER BY RowID

      OPEN @CUR_INSTASK
      
      FETCH NEXT FROM @CUR_INSTASK INTO @n_RowID
             
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @b_success = 1  
         BEGIN TRY      
            EXECUTE nspg_getkey        
            'TaskDetailKey'        
            , 10        
            , @c_TaskDetailKey   OUTPUT        
            , @b_success         OUTPUT        
            , @n_err             OUTPUT        
            , @c_errmsg          OUTPUT        
         END TRY

         BEGIN CATCH
            SET @n_err = 554702
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) 
                           + ': Error Executing nspg_getkey - TaskDetailKey. (lsp_TMCCReleaseFNZ_Wrapper)'
                           + '( ' + @c_errmsg + ' )'
         END CATCH    
                      
         IF @b_success = 0 OR @n_Err <> 0        
         BEGIN        
            SET @n_continue = 3      
            GOTO EXIT_SP
         END        

         BEGIN TRY
            INSERT INTO TASKDETAIL
            (    TaskDetailkey
               , TaskType                 
               , Storerkey             
               , Sku                   
               , Lot                   
               , UOM                   
               , UOMQty                
               , Qty                   
               , FromLoc               
               , LogicalFromLoc        
               , FromID                
               , ToLoc                 
               , LogicalToLoc          
               , ToID                  
               , Caseid                
               , PickMethod            
               , [Status]                
               , StatusMsg             
               , [Priority]              
               , SourcePriority        
               , Holdkey               
               , UserKey               
               , UserPosition          
               , UserKeyOverRide       
               , StartTime             
               , EndTime               
               , SourceType            
               , SourceKey             
               , PickDetailKey         
               , OrderKey              
               , OrderLineNumber       
               , ListKey               
               , WaveKey               
               , ReasonKey             
               , Message01             
               , Message02             
               , Message03             
               , SystemQty             
               , RefTaskKey            
               , LoadKey               
               , AreaKey               
               , DropID                
               , TransitCount          
               , TransitLOC            
               , FinalLOC              
               , FinalID               
               , Groupkey              
               , PendingMoveIn         
               , QtyReplen          
            )

            SELECT 
                 @c_TaskDetailKey
               , WIP.TaskType                
               , WIP.Storerkey               
               , WIP.Sku                     
               , WIP.Lot                     
               , WIP.UOM                     
               , WIP.UOMQty                  
               , WIP.Qty                     
               , WIP.FromLoc                 
               , WIP.LogicalFromLoc          
               , WIP.FromID                  
               , WIP.ToLoc                   
               , WIP.LogicalToLoc            
               , WIP.ToID                    
               , WIP.Caseid                  
               , WIP.PickMethod              
               , WIP.[Status]                  
               , WIP.StatusMsg               
               , WIP.[Priority]                
               , WIP.SourcePriority          
               , WIP.Holdkey                 
               , WIP.UserKey                 
               , WIP.UserPosition            
               , WIP.UserKeyOverRide         
               , WIP.StartTime               
               , WIP.EndTime                 
               , WIP.SourceType              
               , @c_CCKey               
               , WIP.PickDetailKey           
               , WIP.OrderKey                
               , WIP.OrderLineNumber         
               , WIP.ListKey                 
               , WIP.WaveKey                 
               , WIP.ReasonKey               
               , WIP.Message01               
               , WIP.Message02               
               , WIP.Message03               
               , WIP.SystemQty               
               , WIP.RefTaskKey              
               , WIP.LoadKey                 
               , WIP.AreaKey                 
               , WIP.DropID                  
               , WIP.TransitCount            
               , WIP.TransitLOC              
               , WIP.FinalLOC                
               , WIP.FinalID                 
               , WIP.Groupkey                
               , WIP.PendingMoveIn           
               , WIP.QtyReplen               
            FROM TASKDETAIL_WIP WIP WITH (NOLOCK)
            WHERE WIP.RowID = @n_RowID
         END TRY

         BEGIN CATCH
            SET @n_Continue = 3
            SET @n_err = 554703
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Insert into TASKDETAIL Fail. (lsp_TMCCReleaseFNZ_Wrapper)'
                           + '( ' + @c_errmsg + ' )'

            GOTO EXIT_SP
         END CATCH  

         FETCH NEXT FROM @CUR_INSTASK INTO @n_RowID  
      END
      CLOSE @CUR_INSTASK 
      DEALLOCATE @CUR_INSTASK
      
      BEGIN TRY
         INSERT INTO IDS_GeneralLog (udf01, udf02, udf03, udf04, udf05)
         SELECT PickMethod = udf03, GroupKeyTableField = udf04, FilterCode = udf05, LogSource = udf01, LoginUser = @c_UserName
         FROM IDS_GENERALLOG WITH (NOLOCK)
         WHERE udf01 = 'SKURELOPTION'
         AND   udf02 = @c_BatchNo 
      END TRY

      BEGIN CATCH
         SET @n_Continue = 3
         SET @n_err = 554704
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Insert into IDS_GeneralLog Fail. (lsp_TMCCReleaseFNZ_Wrapper)'
                        + '( ' + @c_errmsg + ' )'

         GOTO EXIT_SP
      END CATCH  

      SET @b_success = 1  
      BEGIN TRY      
         EXEC WM.lsp_TaskDetail_WIP_Delete      
           @c_BatchNo = @c_BatchNo     
         , @b_success = @b_success  OUTPUT        
         , @n_err     = @n_err      OUTPUT        
         , @c_errmsg  = @c_errmsg   OUTPUT
         , @c_UserName= @c_UserName             --(Wan)         
      END TRY

      BEGIN CATCH
         SET @n_err = 554705
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) 
                        + ': Error Executing lsp_TaskDetail_WIP_Delete. (lsp_TMCCReleaseFNZ_Wrapper)'
                        + '( ' + @c_errmsg + ' )'
      END CATCH    
                      
      IF @b_success = 0 OR @n_Err <> 0        
      BEGIN        
         SET @n_continue = 3      
         GOTO EXIT_SP
      END 
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END    

   EXIT_SP:
   
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_TMCCReleaseFNZ_Wrapper'
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