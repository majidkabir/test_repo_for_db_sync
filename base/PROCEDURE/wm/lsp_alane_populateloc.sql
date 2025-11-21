SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_ALane_PopulateLoc                               */                                                                                  
/* Creation Date: 2019-07-29                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-1857- SP for populate Lane loc for Assign Lane for     */
/*          - ( Load and MBOL )                                         */
/*                                                                      */                                                                                  
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.0                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */ 
/* 2021-02-05  mingle01 1.1  Add Big Outer Begin try/Catch             */
/*                           Execute Login if @c_UserName<>SUSER_SNAME()*/ 
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_ALane_PopulateLoc] 
      @c_LocationCategory     NVARCHAR(10)   
   ,  @c_Loc                  NVARCHAR(10)   
   ,  @c_Loadkey              NVARCHAR(10)  = ''                                                                                                                   
   ,  @c_MBOLkey              NVARCHAR(10)  = ''  
   ,  @c_ExternOrderkey       NVARCHAR(50)  = ''    
   ,  @c_Consigneekey         NVARCHAR(15)  = ''                             
   ,  @b_Success              INT = 1                 OUTPUT  
   ,  @n_err                  INT = 0                 OUTPUT                                                                                                             
   ,  @c_ErrMsg               NVARCHAR(255)= ''       OUTPUT   
   ,  @c_UserName             NVARCHAR(128)= ''                                                                                                                         

AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt         INT = @@TRANCOUNT  
         ,  @n_Continue          INT = 1

         ,  @c_LP_LaneNumber     NVARCHAR(5) = ''

         ,  @CUR_DEL             CURSOR

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
      SET @b_Success = 1

      SET @c_LoadKey = ISNULL(RTRIM(@c_LoadKey),'')
      SET @c_MBOLKey = ISNULL(RTRIM(@c_MBOLKey),'')

      IF (@c_LoadKey  = '' AND @c_MBOLKey  = '') OR
         (@c_LoadKey <> '' AND @c_MBOLKey <> '')
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 557101
         SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err)
                       + ': Either Load # or Ship Ref. Unit is Mandatory. (lsp_ALane_PopulateLoc)'
         GOTO EXIT_SP
      END
  
      SET @CUR_DEL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LP_LaneNumber
         FROM LOADPLANLANEDETAIL WITH (NOLOCK)
         WHERE Loadkey = @c_Loadkey
         AND ExternOrderkey = @c_ExternOrderkey
         AND ConsigneeKey = @c_Consigneekey
         AND MBOLKey = @c_MBOLkey
         AND Loc = '' 
         ORDER BY LP_LaneNumber 

      OPEN @CUR_DEL   
   
      FETCH NEXT FROM @CUR_DEL INTO @c_LP_LaneNumber

      WHILE @@FETCH_STATUS <> -1 
      BEGIN      
         BEGIN TRY
            DELETE LOADPLANLANEDETAIL
            WHERE Loadkey = @c_Loadkey
            AND ExternOrderkey = @c_ExternOrderkey
            AND ConsigneeKey = @c_Consigneekey
            AND LP_LaneNumber = @c_LP_LaneNumber
            AND MBOLKey = @c_MBOLkey
            AND Loc = ''
         END TRY
         BEGIN CATCH
            SET @n_Continue = 3
            SET @n_Err = 557102
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Delete Loadplanlanedetail Table Fail'
                          + '. (lsp_ALane_PopulateLoc)' 
                    
            IF (XACT_STATE()) = -1  
            BEGIN
               IF @@TRANCOUNT > 0 
               BEGIN
                  ROLLBACK TRAN
               END

               WHILE @@TRANCOUNT > 0 AND @@TRANCOUNT < @n_StartTCnt
               BEGIN
                  BEGIN TRAN
               END
            END 
            GOTO EXIT_SP 
         END CATCH
         
         FETCH NEXT FROM @CUR_DEL INTO @c_LP_LaneNumber                
      END
      CLOSE @CUR_DEL
      DEALLOCATE @CUR_DEL

      SET @c_LP_LaneNumber = '00000'

      SELECT TOP 1 @c_LP_LaneNumber = LP_LaneNumber
      FROM LOADPLANLANEDETAIL WITH (NOLOCK)
      WHERE Loadkey = @c_Loadkey
      AND ExternOrderkey = @c_ExternOrderkey
      AND ConsigneeKey = @c_Consigneekey
      AND MBOLKey = @c_MBOLkey
      ORDER BY LP_LaneNumber Desc

      SET @c_LP_LaneNumber = RIGHT('00000' + CONVERT(NVARCHAR(5), CONVERT( INT, @c_LP_LaneNumber ) + 1),5)

      BEGIN TRY
         INSERT INTO LOADPLANLANEDETAIL
            (  Loadkey
            ,  ExternOrderkey
            ,  Consigneekey
            ,  LP_LaneNumber
            ,  LocationCategory
            ,  Loc
            ,  [Status]
            ,  MBOLKey
            )
         VALUES 
            (  @c_Loadkey
            ,  @c_ExternOrderkey
            ,  @c_Consigneekey
            ,  @c_LP_LaneNumber
            ,  @c_LocationCategory
            ,  @c_Loc
            ,  '0'
            ,  @c_MBOLKey
            )
      END TRY

      BEGIN CATCH
         SET @n_Continue = 3
         SET @n_Err = 557103
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Insert Into Loadplanlanedetail Table Fail'
                       + '. (lsp_ALane_PopulateLoc)' 
                    
         IF (XACT_STATE()) = -1  
         BEGIN
            IF @@TRANCOUNT > 0 
            BEGIN
               ROLLBACK TRAN
            END

            WHILE @@TRANCOUNT > 0 AND @@TRANCOUNT < @n_StartTCnt
            BEGIN
               BEGIN TRAN
            END
         END 
         GOTO EXIT_SP 
      END CATCH
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
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_ALane_PopulateLoc'
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