SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_WaveShip                                        */                                                                                  
/* Creation Date: 2019-04-23                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-1794 - SPs for Wave Control Screens                    */
/*          - ( Wave & MBOL Shipment )                                  */
/*                                                                      */                                                                                  
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.2                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */  
/* 2020-07-08  Wan01    1.0   LFWM-2193 - Ship Reference Unit  Stored   */
/*                            ProceduresSQL queries                     */
/* 2021-02-10  mingle01 1.1   Add Big Outer Begin try/Catch              */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/* 2022-03-07  Wan02    1.2   LFWM-3393 - PROD - CN  MBOL unable mark   */
/*                            ship                                      */
/*                            Enhancement: Not to rollback WMS_ERROR_list*/
/*                            record                                    */
/*                            Add Container Validate as per Exceed      */
/*                            DevOps Combine Script                     */
/************************************************************************/                                                                                  
CREATE   PROC [WM].[lsp_WaveShip] 
      @c_WaveKey              NVARCHAR(10)                     -- Mandatory to pass In Wavekey                                                                                               
   ,  @c_MBOLkey              NVARCHAR(10)  = ''               -- IF Ship By MBOL & Re-Ship, mandatory to pass in MBOLKey    
   ,  @c_ShipMode             NVARCHAR(10)  = ''               -- IF Ship By MBOL & Re-Ship, @c_ShipMode = 'MBOL' , IF Ship By Wave & Re-Ship, @c_ShipMode = 'WAVE'   
   ,  @n_TotalSelectedKeys    INT = 1                          -- Pass in the Total Selected Key Count value
   ,  @n_KeyCount             INT = 0                 OUTPUT   -- Counting Shipped document Key
   ,  @b_Success              INT = 1                 OUTPUT  
   ,  @n_err                  INT = 0                 OUTPUT                                                                                                             
   ,  @c_ErrMsg               NVARCHAR(255)= ''       OUTPUT   
   ,  @n_WarningNo            INT          = 0        OUTPUT   -- Initial to Pass in '1', Pass In the value return By SP except RE-Ship. Reship get logwarningno to pass in
   ,  @c_ProceedWithWarning   CHAR(1)      = 'N'                     
   ,  @c_UserName             NVARCHAR(128)= ''                                                                                                                         
   ,  @n_ErrGroupKey          INT          = 0        OUTPUT   -- Capture Warnings/Questions/Errors/Meassage into WMS_ERROR_LIST Table
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt         INT = @@TRANCOUNT  
         ,  @n_Continue          INT = 1

         ,  @n_RowRef            INT = 0
         ,  @n_MBOLCnt           INT = 0
         ,  @n_TotalWaveMBOL     INT = 0
         ,  @b_ReturnCode        INT = 0
         ,  @n_LogWarningNo      INT = @n_WarningNo   --(Wan02)

         ,  @c_TableName         NVARCHAR(50)   = 'MBOLDETAIL'
         ,  @c_SourceType        NVARCHAR(50)   = 'lsp_WaveShip'

         ,  @c_WriteType         NVARCHAR(20)   = ''

         ,  @n_PosStart          INT = 0   
         ,  @n_PosEnd            INT = 0  
         ,  @c_ReplaceString     NVARCHAR(50) = ''

         ,  @c_WaveKey_MBOL      NVARCHAR(10) = ''    --(Wan01)
         
         ,  @c_Facility          NVARCHAR(5)  = ''    --(Wan02)
         ,  @c_Storerkey         NVARCHAR(15) = ''    --(Wan02)         
         ,  @c_MBOLGenContainer  NVARCHAR(30) = ''    --(Wan02)

         ,  @CUR_MBOLMGMT        CURSOR               --(Wan01)
         ,  @CUR_MBOL            CURSOR
         ,  @CUR_MER             CURSOR
         
         ,  @c_Refkey1        NVARCHAR(20)   = ''                    --(Wan02)
         ,  @c_Refkey2        NVARCHAR(20)   = ''                    --(Wan02)
         ,  @c_Refkey3        NVARCHAR(20)   = ''                    --(Wan02)
         
         ,  @CUR_ERRLIST      CURSOR                                 --(Wan02)
         
   DECLARE  @t_WMSErrorList   TABLE                                  --(Wan02)
         (  RowID             INT            IDENTITY(1,1) 
         ,  TableName         NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  SourceType        NVARCHAR(50)   NOT NULL DEFAULT('')
         ,  Refkey1           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  Refkey2           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  Refkey3           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  WriteType         NVARCHAR(50)   NOT NULL DEFAULT('')
         ,  LogWarningNo      INT            NOT NULL DEFAULT(0)
         ,  ErrCode           INT            NOT NULL DEFAULT(0)
         ,  Errmsg            NVARCHAR(255)  NOT NULL DEFAULT('')  
         )


   DECLARE @tMBOL TABLE
      (  RowRef         INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
      ,  MBOLKey        NVARCHAR(10)   NOT NULL DEFAULT('') 
      ,  ValidatePass   BIT            NOT NULL DEFAULT(0)    
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

      SET @b_Success = 1
      IF @n_ErrGroupKey IS NULL
      BEGIN
         SET @n_ErrGroupKey = 0
      END

      SET @c_MBOLKey = ISNULL(@c_MBOLKey,'')
      SET @c_ShipMode= ISNULL(@c_ShipMode,'')

      IF @c_ShipMode = ''
      BEGIN
         SET @c_ShipMode = 'WAVE'
         IF @c_MBOLKey <> ''
         BEGIN
            SET @c_ShipMode = 'MBOL'
         END  
      END

      IF @n_WarningNo < 2
      BEGIN
         IF @c_ShipMode = 'WAVE' 
         BEGIN
            INSERT INTO @tMBOL (MBOLKey)
            SELECT DISTINCT MB.MBOLkey
            FROM WAVEDETAIL WD  WITH (NOLOCK)
            JOIN MBOLDETAIL MBD WITH (NOLOCK) ON (WD.Orderkey = MBD.Orderkey)
            JOIN MBOL       MB  WITH (NOLOCK) ON (MBD.MBOLkey = MB.MBOLkey)
            WHERE WD.WaveKey = @c_WaveKey
            AND  MB.[Status] < '9'
            ORDER BY MB.MBOLkey

            SET @n_TotalWaveMBOL = 0
            SELECT TOP 1 @n_TotalWaveMBOL = RowRef
            FROM @tMBOL
            ORDER BY RowRef DESC
         END
         ELSE IF @c_ShipMode = 'MBOL' 
         BEGIN
            INSERT INTO @tMBOL (MBOLKey)
            VALUES (@c_MBOLkey)
         END 
         
         --(Wan02) - START
         SELECT TOP 1 @c_Facility = o.Facility
                  ,  @c_Storerkey = o.StorerKey
         FROM @tMBOL t
         JOIN MBOLDETAIL AS m WITH (NOLOCK) ON m.MbolKey = t.MBOLKey 
         JOIN dbo.ORDERS AS o WITH (NOLOCK) ON m.OrderKey = o.OrderKey
         ORDER BY t.RowRef
               ,  m.MbolLineNumber 
               
         SELECT @c_MBOLGenContainer = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'MBOLGenContainer') 
         --(Wan02) - END       

         SET @CUR_MBOL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT RowRef, MBOLKey
         FROM @tMBOL
         ORDER BY RowRef

         OPEN @CUR_MBOL
      
         FETCH NEXT FROM @CUR_MBOL INTO @n_RowRef, @c_MBOLKey                                                                                
                                       
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            BEGIN TRY
               EXEC [WM].[lsp_Validate_WaveShip_Std]
                  @c_MBOLkey  = @c_MBOLkey 
               ,  @b_Success  = @b_Success   OUTPUT  
               ,  @n_err      = @n_err       OUTPUT                   
               ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
            END TRY
            BEGIN CATCH
               SET @n_Continue = 3
               SET @n_err = 556760
               SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err)
                             + ': ERROR lsp_Validate_WaveShip_Std. (lsp_WaveShip)'

               --(Wan02) - START               
               INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
               VALUES (@c_TableName, @c_SourceType, @c_WaveKey, @c_MBOLkey, '', 'ERROR', 0, @n_err, @c_errmsg)   
                     
               --EXEC [WM].[lsp_WriteError_List] 
               --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
               --   ,  @c_TableName   = @c_TableName
               --   ,  @c_SourceType  = @c_SourceType
               --   ,  @c_Refkey1     = @c_WaveKey
               --   ,  @c_Refkey2     = @c_MBOLkey
               --   ,  @c_Refkey3     = ''
               --   ,  @c_WriteType   = 'ERROR' 
               --   ,  @n_err2        = @n_err 
               --   ,  @c_errmsg2     = @c_errmsg 
               --   ,  @b_Success     = @b_Success   OUTPUT 
               --   ,  @n_err         = @n_err       OUTPUT 
               --   ,  @c_errmsg      = @c_errmsg    OUTPUT 
               GOTO VALIDATE_NEXT_MBOL    
               --(Wan02) - END                 
            END CATCH 

            UPDATE @tMBOL SET ValidatePass = 1
            WHERE RowRef = @n_RowRef

            VALIDATE_NEXT_MBOL:
            FETCH NEXT FROM @CUR_MBOL INTO @n_RowRef, @c_MBOLKey
         END 
              
         IF @c_ShipMode = 'MBOL' 
         BEGIN
            IF EXISTS ( SELECT 1 FROM  @tMBOL
                        WHERE ValidatePass = 0 )
            BEGIN
               GOTO EXIT_SP
            END
         END    
      END

      WHILE @@TRANCOUNT > 0 
      BEGIN
         COMMIT TRAN
      END

      SHIP_WAVE:
         IF @c_ShipMode = 'WAVE' 
         BEGIN
            SET @CUR_MBOL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT MBOLKey
            FROM @tMBOL
            WHERE ValidatePass = 1
            ORDER BY RowRef

            OPEN @CUR_MBOL
      
            FETCH NEXT FROM @CUR_MBOL INTO @c_MBOLKey                                                                                
                                       
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               SET @n_MBOLCnt = @n_MBOLCnt + 1

               SET @n_Continue = 1

               IF @n_WarningNo < 2
               BEGIN                  
                  EXEC [dbo].[isp_ValidateMBOL]  
                       @c_MBOLkey   = @c_MBOLkey
                     , @b_ReturnCode= @b_ReturnCode   OUTPUT
                     , @n_Err       = @n_Err          OUTPUT 
                     , @c_ErrMsg    = @c_ErrMsg       OUTPUT 

                  IF @b_ReturnCode < 0  -- Fail
                  BEGIN
                     SET @n_Continue = 3
                     SET @n_Err = 556756
                     SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Validate MBOL Fail - Wave. (lsp_WaveShip)'   
                                 + '(' + @c_ErrMsg + ')' 
                     
                     --(Wan02) - START               
                     INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
                     VALUES (@c_TableName, @c_SourceType, @c_WaveKey, @c_MBOLkey, '', 'ERROR', 0, @n_err, @c_errmsg)                    
                     --EXEC [WM].[lsp_WriteError_List] 
                     --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                     --   ,  @c_TableName   = @c_TableName
                     --   ,  @c_SourceType  = @c_SourceType
                     --   ,  @c_Refkey1     = @c_WaveKey
                     --   ,  @c_Refkey2     = @c_MBOLkey
                     --   ,  @c_Refkey3     = ''
                     --   ,  @c_WriteType   = 'ERROR' 
                     --   ,  @n_err2        = @n_err 
                     --   ,  @c_errmsg2     = @c_errmsg 
                     --   ,  @b_Success     = @b_Success   OUTPUT 
                     --   ,  @n_err         = @n_err       OUTPUT 
                     --   ,  @c_errmsg      = @c_errmsg    OUTPUT
                     --(Wan02) - END

                     --GOTO EXIT_SP
                     GOTO NEXT_MBOL
                  END  

                  IF @b_ReturnCode = 1  -- Warning
                  BEGIN
                     SET @CUR_MER = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT MER.LineText
                     FROM MBOLErrorReport MER WITH (NOLOCK)
                     WHERE MER.MBOLKey = @c_MBOLKey
                     AND MER.[Type] in ('WarningMsg')       --2020-07-09
                     ORDER BY MER.SeqNo

                     OPEN @CUR_MER
      
                     FETCH NEXT FROM @CUR_MER INTO @c_errmsg                                                                                
                                       
                     WHILE @@FETCH_STATUS <> -1
                     BEGIN
                        SET @n_LogWarningNo = 2
                        
                        --(Wan02) - START               
                        INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
                        VALUES (@c_TableName, @c_SourceType, @c_WaveKey, @c_MBOLkey, '', 'WARNING', @n_LogWarningNo, @n_err, @c_errmsg)  
                         
                        --EXEC [WM].[lsp_WriteError_List] 
                        --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                        --   ,  @c_TableName   = @c_TableName
                        --   ,  @c_SourceType  = @c_SourceType
                        --   ,  @c_Refkey1     = @c_WaveKey
                        --   ,  @c_Refkey2     = @c_MBOLkey
                        --   ,  @c_Refkey3     = ''
                        --   ,  @n_LogWarningNo= @n_LogWarningNo
                        --   ,  @c_WriteType   = 'WARNING' 
                        --   ,  @n_err2        = 0 
                        --   ,  @c_errmsg2     = @c_errmsg 
                        --   ,  @b_Success     = @b_Success   OUTPUT 
                        --   ,  @n_err         = @n_err       OUTPUT 
                        --   ,  @c_errmsg      = @c_errmsg    OUTPUT
                        --(Wan02) - END

                        FETCH NEXT FROM @CUR_MER INTO @c_errmsg       
                     END
                     CLOSE @CUR_MER
                     DEALLOCATE @CUR_MER

                     GOTO NEXT_MBOL
                  END
               END

               --(Wan02) - START                 
               BEGIN TRAN
               IF @c_MBOLGenContainer = '1'
               BEGIN
                  BEGIN TRY
                     EXEC isp_MBOLGenContainer
                       @c_MBOLkey   = @c_MBOLkey
                     , @b_Success   = @b_Success   OUTPUT
                     , @n_Err       = @n_Err       OUTPUT 
                     , @c_ErrMsg    = @c_ErrMsg    OUTPUT 
                     
                     IF @b_Success = 0
                     BEGIN
                        SET @n_Continue = 3
                     END
                  END TRY
               
                  BEGIN CATCH
                     SET @n_Continue = 3
                     SET @c_ErrMsg = ERROR_MESSAGE()
                  END CATCH
                  
                  IF @n_Continue = 3
                  BEGIN
                     SET @n_Err = 556763
                     SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Generating Container - Wave. (lsp_WaveShip)'   
                                    + '(' + @c_ErrMsg + ')' 
                     
                     --(Wan02) - START               
                     INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
                     VALUES (@c_TableName, @c_SourceType, @c_WaveKey, @c_MBOLkey, '', 'ERROR', 0, @n_err, @c_errmsg)                 
                     --EXEC [WM].[lsp_WriteError_List] 
                     --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                     --   ,  @c_TableName   = @c_TableName
                     --   ,  @c_SourceType  = @c_SourceType
                     --   ,  @c_Refkey1     = @c_WaveKey
                     --   ,  @c_Refkey2     = @c_MBOLkey
                     --   ,  @c_Refkey3     = ''
                     --   ,  @c_WriteType   = 'ERROR' 
                     --   ,  @n_err2        = @n_err 
                     --   ,  @c_errmsg2     = @c_errmsg 
                     --   ,  @b_Success     = @b_Success   OUTPUT 
                     --   ,  @n_err         = @n_err       OUTPUT 
                     --   ,  @c_errmsg      = @c_errmsg    OUTPUT

                     GOTO NEXT_MBOL
                  END
               END      
               --(Wan02) - END
            
               BEGIN TRY
                  EXEC [dbo].[isp_ShipMBOL]  
                       @c_MBOLkey   = @c_MBOLkey
                     , @b_Success   = @b_Success      OUTPUT
                     , @n_Err       = @n_Err          OUTPUT 
                     , @c_ErrMsg    = @c_ErrMsg       OUTPUT 
                     
                     IF @b_Success = 0                --(Wan02)
                     BEGIN
                        SET @n_Continue = 3
                     END
               END TRY

               BEGIN CATCH
                  SET @n_Continue = 3
                  SET @c_ErrMsg = ERROR_MESSAGE()
               END CATCH
               
               IF @n_Continue = 3                     --(Wan02)
               BEGIN
                  SET @n_Err = 556751
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing isp_ShipMBOL - Wave. (lsp_WaveShip)'   
                              + '(' + @c_ErrMsg + ')' 
                  
                  --(Wan02) - START               
                  INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
                  VALUES (@c_TableName, @c_SourceType, @c_WaveKey, @c_MBOLkey, '', 'ERROR', 0, @n_err, @c_errmsg)  
                       
                  --EXEC [WM].[lsp_WriteError_List] 
                  --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                  --   ,  @c_TableName   = @c_TableName
                  --   ,  @c_SourceType  = @c_SourceType
                  --   ,  @c_Refkey1     = @c_WaveKey
                  --   ,  @c_Refkey2     = @c_MBOLkey
                  --   ,  @c_Refkey3     = ''
                  --   ,  @c_WriteType   = 'ERROR' 
                  --   ,  @n_err2        = @n_err 
                  --   ,  @c_errmsg2     = @c_errmsg 
                  --   ,  @b_Success     = @b_Success   OUTPUT 
                  --   ,  @n_err         = @n_err       OUTPUT 
                  --   ,  @c_errmsg      = @c_errmsg    OUTPUT
               
                  --IF (XACT_STATE()) = -1  
                  --BEGIN
                  --   IF @@TRANCOUNT > 0 
                  --   BEGIN
                  --      ROLLBACK TRAN
                  --   END

                  --   WHILE @@TRANCOUNT > 0 AND @@TRANCOUNT < @n_StartTCnt
                  --   BEGIN
                  --      BEGIN TRAN
                  --   END
                  --END
                   
                  --IF @b_Success = 0 OR @n_Err > 0       
                  --BEGIN
                  --   SET @n_Continue = 3
                  --END
                  --(Wan02) - END

                  GOTO NEXT_MBOL
               END
               
               BEGIN TRY
                  UPDATE MBOL 
                  SET [Status] = '9'
                  WHERE MBOLKey = @c_MBOLkey
               END TRY

               BEGIN CATCH
                  SET @n_Continue = 3
                  SET @n_Err = 556752
                  SET @c_ErrMsg = ERROR_MESSAGE()
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Update MBOL Table Fail - Wave. (lsp_WaveShip)'   
                                + '(' + @c_ErrMsg + ')' 
                  
                  --(Wan02) - START               
                  INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
                  VALUES (@c_TableName, @c_SourceType, @c_WaveKey, @c_MBOLkey, '', 'ERROR', 0, @n_err, @c_errmsg)                
                       
                  --EXEC [WM].[lsp_WriteError_List] 
                  --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                  --   ,  @c_TableName   = @c_TableName
                  --   ,  @c_SourceType  = @c_SourceType
                  --   ,  @c_Refkey1     = @c_WaveKey
                  --   ,  @c_Refkey2     = @c_MBOLkey
                  --   ,  @c_Refkey3     = ''
                  --   ,  @c_WriteType   = 'ERROR' 
                  --   ,  @n_err2        = @n_err 
                  --   ,  @c_errmsg2     = @c_errmsg 
                  --   ,  @b_Success     = @b_Success   OUTPUT 
                  --   ,  @n_err         = @n_err       OUTPUT 
                  --   ,  @c_errmsg      = @c_errmsg    OUTPUT
     
                  --IF (XACT_STATE()) = -1  
                  --BEGIN
                  --   IF @@TRANCOUNT > 0 
                  --   BEGIN
                  --      ROLLBACK TRAN
                  --   END

                  --   WHILE @@TRANCOUNT > 0 AND @@TRANCOUNT < @n_StartTCnt
                  --   BEGIN
                  --      BEGIN TRAN
                  --   END
                  --END 
                  --(Wan02) - END
                  GOTO NEXT_MBOL
               END CATCH
               
               SET @c_ErrMsg = 'Shipment is successfull.'

               INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
               VALUES (@c_TableName, @c_SourceType, @c_WaveKey, @c_MBOLkey, '', 'MESSAGE', 0, @n_err, @c_errmsg)  
         
               --SET @c_WriteType = 'MESSAGE'  
               --EXEC [WM].[lsp_WriteError_List] 
               --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
               --   ,  @c_TableName   = @c_TableName
               --   ,  @c_SourceType  = @c_SourceType
               --   ,  @c_Refkey1     = @c_WaveKey
               --   ,  @c_Refkey2     = @c_MBOLkey
               --   ,  @c_Refkey3     = ''
               --   ,  @c_WriteType   = @c_WriteType
               --   ,  @n_err2        = 0 
               --   ,  @c_errmsg2     = @c_ErrMsg
               --   ,  @b_Success     = @b_Success   OUTPUT 
               --   ,  @n_err         = @n_err       OUTPUT 
               --   ,  @c_errmsg      = @c_errmsg    OUTPUT

               NEXT_MBOL:
               
               --(Wan02) - START
               IF (XACT_STATE()) = -1  
               BEGIN
                  SET @n_Continue = 3
               END 
               
               IF @n_Continue = 3
               BEGIN
                  IF @@TRANCOUNT > 0 
                  BEGIN
                     ROLLBACK TRAN
                  END
               END
               ELSE
               BEGIN
                  WHILE @@TRANCOUNT > 0
                  BEGIN
                     COMMIT TRAN
                  END
               END
              
               SET @CUR_ERRLIST = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT   twl.TableName         
                     ,  twl.SourceType        
                     ,  twl.Refkey1           
                     ,  twl.Refkey2           
                     ,  twl.Refkey3           
                     ,  twl.WriteType         
                     ,  twl.LogWarningNo      
                     ,  twl.ErrCode           
                     ,  twl.Errmsg               
               FROM @t_WMSErrorList AS twl
               ORDER BY twl.RowID
   
               OPEN @CUR_ERRLIST
   
               FETCH NEXT FROM @CUR_ERRLIST INTO   @c_TableName         
                                                 , @c_SourceType        
                                                 , @c_Refkey1           
                                                 , @c_Refkey2           
                                                 , @c_Refkey3           
                                                 , @c_WriteType         
                                                 , @n_LogWarningNo      
                                                 , @n_Err           
                                                 , @c_Errmsg            
   
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                  ,  @c_TableName   = @c_TableName
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_Refkey1
                  ,  @c_Refkey2     = @c_Refkey2
                  ,  @c_Refkey3     = @c_Refkey3
                  ,  @n_LogWarningNo= @n_LogWarningNo
                  ,  @c_WriteType   = @c_WriteType
                  ,  @n_err2        = @n_err 
                  ,  @c_errmsg2     = @c_errmsg 
                  ,  @b_Success     = @b_Success    
                  ,  @n_err         = @n_err        
                  ,  @c_errmsg      = @c_errmsg         
     
                  FETCH NEXT FROM @CUR_ERRLIST INTO   @c_TableName         
                                                    , @c_SourceType        
                                                    , @c_Refkey1           
                                                    , @c_Refkey2           
                                                    , @c_Refkey3           
                                                    , @c_WriteType         
                                                    , @n_LogWarningNo      
                                                    , @n_Err           
                                                    , @c_Errmsg     
               END
               CLOSE @CUR_ERRLIST
               DEALLOCATE @CUR_ERRLIST
               
               DELETE FROM @t_WMSErrorList;
               --(Wan02) - END
               
               FETCH NEXT FROM @CUR_MBOL INTO @c_MBOLKey 
            END
            CLOSE @CUR_MBOL
            DEALLOCATE @CUR_MBOL
         END

      SHIP_MBOL:
         IF @c_ShipMode = 'MBOL'
         BEGIN
            IF @n_WarningNo < 2  
            BEGIN
               EXEC [dbo].[isp_ValidateMBOL]  
                    @c_MBOLkey   = @c_MBOLkey
                  , @b_ReturnCode= @b_ReturnCode   OUTPUT
                  , @n_Err       = @n_Err          OUTPUT 
                  , @c_ErrMsg    = @c_ErrMsg       OUTPUT 

               IF @b_ReturnCode < 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 556757
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Validate MBOL Fail - Ship Ref.Unit. (lsp_WaveShip)'   
                                 + '(' + @c_ErrMsg + ')' 

                  --(Wan02) - START
                  INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
                  VALUES (@c_TableName, @c_SourceType, @c_WaveKey, @c_MBOLKey, '', 'ERROR', @n_LogWarningNo, @n_err, @c_errmsg)                                    
                  --EXEC [WM].[lsp_WriteError_List] 
                  --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                  --   ,  @c_TableName   = @c_TableName
                  --   ,  @c_SourceType  = @c_SourceType
                  --   ,  @c_Refkey1     = @c_WaveKey
                  --   ,  @c_Refkey2     = @c_MBOLkey
                  --   ,  @c_Refkey3     = ''
                  --   ,  @c_WriteType   = 'ERROR' 
                  --   ,  @n_err2        = @n_err 
                  --   ,  @c_errmsg2     = @c_errmsg 
                  --   ,  @b_Success     = @b_Success   OUTPUT 
                  --   ,  @n_err         = @n_err       OUTPUT 
                  --   ,  @c_errmsg      = @c_errmsg    OUTPUT
                  --(Wan02) - END
                  GOTO EXIT_SP                      
               END  

               IF @b_ReturnCode = 1
               BEGIN
                  SET @CUR_MER = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT MER.LineText
                  FROM MBOLErrorReport MER WITH (NOLOCK)
                  WHERE MER.MBOLKey = @c_MBOLKey
                  AND MER.[Type] in ('WarningMsg')       --2020-07-09
                  ORDER BY MER.SeqNo

                  OPEN @CUR_MER
      
                  FETCH NEXT FROM @CUR_MER INTO @c_errmsg                                                                                
                                       
                  WHILE @@FETCH_STATUS <> -1
                  BEGIN
                     SET @n_LogWarningNo = 2   
                     
                     --(Wan02) - START
                     INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
                     VALUES (@c_TableName, @c_SourceType, @c_WaveKey, @c_MBOLKey, '', 'WARNING', @n_LogWarningNo, @n_err, @c_errmsg)                    
                     --EXEC [WM].[lsp_WriteError_List] 
                     --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                     --   ,  @c_TableName   = @c_TableName
                     --   ,  @c_SourceType  = @c_SourceType
                     --   ,  @c_Refkey1     = @c_WaveKey
                     --   ,  @c_Refkey2     = @c_MBOLkey
                     --   ,  @c_Refkey3     = ''
                     --   ,  @n_LogWarningNo= @n_LogWarningNo
                     --   ,  @c_WriteType   = 'WARNING' 
                     --   ,  @n_err2        = 0 
                     --   ,  @c_errmsg2     = @c_errmsg 
                     --   ,  @b_Success     = @b_Success   OUTPUT 
                     --   ,  @n_err         = @n_err       OUTPUT 
                     --   ,  @c_errmsg      = @c_errmsg    OUTPUT
                     --(Wan02) - END
                     FETCH NEXT FROM @CUR_MER INTO @c_errmsg       
                  END
                  CLOSE @CUR_MER
                  DEALLOCATE @CUR_MER

                  GOTO EXIT_SP
               END
            END

            BEGIN TRAN                 --(Wan02)
            --(Wan02) - START    
            IF @c_MBOLGenContainer = '1'
            BEGIN
               BEGIN TRY
                  EXEC isp_MBOLGenContainer
                     @c_MBOLkey   = @c_MBOLkey
                  , @b_Success   = @b_Success   OUTPUT
                  , @n_Err       = @n_Err       OUTPUT 
                  , @c_ErrMsg    = @c_ErrMsg    OUTPUT 
                  
                  IF @b_Success = 0
                  BEGIN
                     SET @n_Continue = 3
                  END
               END TRY
               BEGIN CATCH
                  SET @n_Continue = 3
                  SET @c_ErrMsg = ERROR_MESSAGE()
               END CATCH
                 
               IF @n_Continue = 3
               BEGIN
                  SET @n_Err = 556764
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Generating Container - Ship Ref.Unit. (lsp_WaveShip)'   
                                 + '(' + @c_ErrMsg + ')' 

                  --(Wan02) - START
                  INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
                  VALUES (@c_TableName, @c_SourceType, @c_WaveKey, @c_MBOLKey, '', 'ERROR', 0, @n_err, @c_errmsg) 

                  GOTO EXIT_SP                      
               END
            END
            --(Wan02) - END

            BEGIN TRY
               EXEC [dbo].[isp_ShipMBOL]  
                    @c_MBOLkey   = @c_MBOLkey
                  , @b_Success   = @b_Success      OUTPUT
                  , @n_Err       = @n_Err          OUTPUT 
                  , @c_ErrMsg    = @c_ErrMsg       OUTPUT 
                  
               IF @b_Success = 0 
               BEGIN
                  SET @n_Continue = 3
               END  
            END TRY
            --(Wan02) - START
            BEGIN CATCH
               SET @n_Continue = 3
               SET @c_ErrMsg = ERROR_MESSAGE()
            END CATCH
            
            IF @n_Continue = 3
            BEGIN
               SET @n_Err = 556753
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing isp_ShipMBOL - Ship Ref.Unit. (lsp_WaveShip)'   
                             + '(' + @c_ErrMsg + ')' 
               

               INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
               VALUES (@c_TableName, @c_SourceType, @c_WaveKey, @c_MBOLKey, '', 'ERROR', 0, @n_err, @c_errmsg) 
               
               GOTO EXIT_SP         
               --EXEC [WM].[lsp_WriteError_List] 
               --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
               --   ,  @c_TableName   = @c_TableName
               --   ,  @c_SourceType  = @c_SourceType
               --   ,  @c_Refkey1     = @c_WaveKey
               --   ,  @c_Refkey2     = @c_MBOLkey
               --   ,  @c_Refkey3     = ''
               --   ,  @c_WriteType   = 'ERROR' 
               --   ,  @n_err2        = @n_err 
               --   ,  @c_errmsg2     = @c_errmsg 
               --   ,  @b_Success     = @b_Success   OUTPUT 
               --   ,  @n_err         = @n_err       OUTPUT 
               --   ,  @c_errmsg      = @c_errmsg    OUTPUT

               --IF (XACT_STATE()) = -1  
               --BEGIN
               --   IF @@TRANCOUNT > 0 
               --   BEGIN
               --      ROLLBACK TRAN
               --   END
               --   WHILE @@TRANCOUNT > 0 AND @@TRANCOUNT < @n_StartTCnt
               --   BEGIN
               --      BEGIN TRAN
               --   END
               --END  
            END 

            --IF @b_Success = 0 OR @n_Err> 0 
            --BEGIN
            --   SET @n_Continue = 3
            --   GOTO EXIT_SP
            --END
            --(Wan02) - END
            --BEGIN TRAN
            BEGIN TRY
               UPDATE MBOL 
               SET [Status] = '9'
               WHERE MBOLKey = @c_MBOLkey
            END TRY
            
            BEGIN CATCH
               SET @n_Continue = 3
               SET @n_Err = 556754
               SET @c_ErrMsg = ERROR_MESSAGE()
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Update MBOL Table Fail - Ship Ref.Unit. (lsp_WaveShip)'   
                             + '(' + @c_ErrMsg + ')' 
               --(Wan02) - START
               INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
               VALUES (@c_TableName, @c_SourceType, @c_WaveKey, @c_MBOLKey, '', 'ERROR', 0, @n_err, @c_errmsg)          
               --EXEC [WM].[lsp_WriteError_List] 
               --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
               --   ,  @c_TableName   = @c_TableName
               --   ,  @c_SourceType  = @c_SourceType
               --   ,  @c_Refkey1     = @c_WaveKey
               --   ,  @c_Refkey2     = @c_MBOLkey
               --   ,  @c_Refkey3     = ''
               --   ,  @c_WriteType   = 'ERROR' 
               --   ,  @n_err2        = @n_err 
               --   ,  @c_errmsg2     = @c_errmsg 
               --   ,  @b_Success     = @b_Success   OUTPUT 
               --   ,  @n_err         = @n_err       OUTPUT 
               --   ,  @c_errmsg      = @c_errmsg    OUTPUT
               
               --IF (XACT_STATE()) = -1  
               --BEGIN
               --   IF @@TRANCOUNT > 0 
               --   BEGIN
               --      ROLLBACK TRAN
               --   END

               --   WHILE @@TRANCOUNT > 0 AND @@TRANCOUNT < @n_StartTCnt
               --   BEGIN
               --      BEGIN TRAN
               --   END
               --END 
               --(Wan02) - END
               GOTO EXIT_SP 
            END CATCH

            --(Wan01) - START
            IF @c_WaveKey = ''
            BEGIN
               SET @c_WaveKey_MBOL = ''
               SET @CUR_MBOLMGMT = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT DISTINCT WD.WaveKey
               FROM MBOLDETAIL MD  WITH (NOLOCK)
               JOIN WAVEDETAIL WD  WITH (NOLOCK) ON MD.Orderkey = WD.Orderkey
               WHERE MD.MBOLkey = @c_MBOLkey

               OPEN @CUR_MBOLMGMT

               FETCH NEXT FROM @CUR_MBOLMGMT INTO @c_WaveKey_MBOL 

               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  IF NOT EXISTS (SELECT 1 
                                 FROM WAVEDETAIL WD WITH (NOLOCK) 
                                 JOIN ORDERS     OH WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey
                                 WHERE WD.WaveKey = @c_WaveKey_MBOL
                                 AND   OH.[Status] < '9'
                                 )
                  BEGIN
                     BEGIN TRY
                        UPDATE WAVE 
                        SET [Status] = '9'
                        WHERE Wavekey = @c_Wavekey
                     END TRY
            
                     BEGIN CATCH
                        SET @n_Continue = 3
                        SET @n_Err = 556762
                        SET @c_ErrMsg = ERROR_MESSAGE()
                        SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Update WAVE Table Fail - Ship Ref. Management. (lsp_WaveShip)'   
                                       + '(' + @c_ErrMsg + ')' 
                       
                        --(Wan02) - START
                        INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
                        VALUES (@c_TableName, @c_SourceType, @c_WaveKey, @c_MBOLKey, '', 'ERROR', 0, @n_err, @c_errmsg)  
                        --EXEC [WM].[lsp_WriteError_List] 
                        --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                        --   ,  @c_TableName   = @c_TableName
                        --   ,  @c_SourceType  = @c_SourceType
                        --   ,  @c_Refkey1     = @c_WaveKey
                        --   ,  @c_Refkey2     = @c_MBOLKey
                        --   ,  @c_Refkey3     = ''
                        --   ,  @c_WriteType   = 'ERROR' 
                        --   ,  @n_err2        = @n_err 
                        --   ,  @c_errmsg2     = @c_errmsg 
                        --   ,  @b_Success     = @b_Success   OUTPUT 
                        --   ,  @n_err         = @n_err       OUTPUT 
                        --   ,  @c_errmsg      = @c_errmsg    OUTPUT
                        
                        --IF (XACT_STATE()) = -1  
                        --BEGIN
                        --   IF @@TRANCOUNT > 0 
                        --   BEGIN
                        --      ROLLBACK TRAN
                        --   END
                        --
                        --   WHILE @@TRANCOUNT > 0 AND @@TRANCOUNT < @n_StartTCnt
                        --   BEGIN
                        --      BEGIN TRAN
                        --   END
                        --END 
                        --(Wan02) - END

                        GOTO EXIT_SP 
                     END CATCH
                  END

                  FETCH NEXT FROM @CUR_MBOLMGMT INTO @c_WaveKey_MBOL 
               END
               CLOSE @CUR_MBOLMGMT
               DEALLOCATE @CUR_MBOLMGMT
            END
            --(Wan01) - END

            SET @c_ErrMsg = 'Shipment is successful.'

            --(Wan02) - START
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
            VALUES (@c_TableName, @c_SourceType, @c_WaveKey, @c_MBOLKey, '', 'MESSAGE', 0, @n_err, @c_errmsg)  
            SET @c_WriteType = 'MESSAGE'  
            --EXEC [WM].[lsp_WriteError_List] 
            --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            --   ,  @c_TableName   = @c_TableName
            --   ,  @c_SourceType  = @c_SourceType
            --   ,  @c_Refkey1     = @c_WaveKey
            --   ,  @c_Refkey2     = @c_MBOLkey
            --   ,  @c_Refkey3     = ''
            --   ,  @c_WriteType   = @c_WriteType
            --   ,  @n_err2        = 0 
            --   ,  @c_errmsg2     = @c_errmsg 
            --   ,  @b_Success     = @b_Success   OUTPUT 
            --   ,  @n_err         = @n_err       OUTPUT 
            --   ,  @c_errmsg      = @c_errmsg    OUTPUT
            --(Wan02) - END
         END
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      --(Wan02)
      INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
      VALUES (@c_TableName, @c_SourceType, @c_WaveKey, @c_MBOLKey, '', 'ERROR', 0, @n_err, @c_errmsg)  
      
      GOTO EXIT_SP_WITH_ERROR_CATCH
   END CATCH
   --(mingle01) - END
EXIT_SP:
   IF  @n_Warningno >= 1 
   BEGIN
      IF @n_Warningno <= 2
      BEGIN
         IF @c_ShipMode = 'WAVE' AND @n_MBOLCnt = @n_TotalWaveMBOL 
         BEGIN
            SET @n_KeyCount = @n_TotalSelectedKeys  
         END

         IF  @c_ShipMode = 'MBOL' 
         BEGIN  
            IF @n_KeyCount < @n_TotalSelectedKeys
            BEGIN
               SET @n_KeyCount = @n_KeyCount + 1
            END
         END 
      END

      IF @n_LogWarningNo = 0 AND @n_KeyCount = @n_TotalSelectedKeys  
      BEGIN
         IF @n_Continue = 1 AND @c_WaveKey <> ''                        --(Wan01)
         BEGIN
            IF NOT EXISTS (SELECT 1 
                           FROM WAVEDETAIL WD WITH (NOLOCK) 
                           JOIN ORDERS     OH WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey
                           WHERE WD.WaveKey = @c_WaveKey
                           AND   OH.[Status] < '9'
                           )
            BEGIN
               BEGIN TRY
                  UPDATE WAVE 
                  SET [Status] = '9'
                  WHERE Wavekey = @c_Wavekey
               END TRY
         
               BEGIN CATCH
                  SET @n_Continue = 3
                  SET @n_Err = 556755
                  SET @c_ErrMsg = ERROR_MESSAGE()
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Update WAVE Table Fail. (lsp_WaveShip)'   
                                 + '(' + @c_ErrMsg + ')' 
                  
                  --(Wan02) - START
                  INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
                  VALUES (@c_TableName, @c_SourceType, @c_WaveKey, @c_MBOLKey, '', 'ERROR', 0, @n_err, @c_errmsg)   
                  --EXEC [WM].[lsp_WriteError_List] 
                  --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                  --   ,  @c_TableName   = @c_TableName
                  --   ,  @c_SourceType  = @c_SourceType
                  --   ,  @c_Refkey1     = @c_WaveKey
                  --   ,  @c_Refkey2     = @c_MBOLKey
                  --   ,  @c_Refkey3     = ''
                  --   ,  @c_WriteType   = 'ERROR' 
                  --   ,  @n_err2        = @n_err 
                  --   ,  @c_errmsg2     = @c_errmsg 
                  --   ,  @b_Success     = @b_Success   OUTPUT 
                  --   ,  @n_err         = @n_err       OUTPUT 
                  --   ,  @c_errmsg      = @c_errmsg    OUTPUT

                  --IF (XACT_STATE()) = -1  
                  --BEGIN
                  --   IF @@TRANCOUNT > 0 
                  --   BEGIN
                  --      ROLLBACK TRAN
                  --   END

                  --   WHILE @@TRANCOUNT > 0 AND @@TRANCOUNT < @n_StartTCnt
                  --   BEGIN
                  --      BEGIN TRAN
                  --   END
                  --END 
                  --(Wan02) - END
               END CATCH
            END
         END
      END
   END
   --START
   --IF @n_ErrGroupKey = 0                                     --(Wan02)
   IF NOT EXISTS (SELECT 1 FROM @t_WMSErrorList)               --(Wan02)
   BEGIN
      SET @c_ErrMsg = 'No Shipment To Process.'

      INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
      VALUES (@c_TableName, @c_SourceType, @c_WaveKey, @c_MBOLKey, '', 'MESSAGE', 0, @n_err, @c_errmsg) 
   END
   --END
   
   EXIT_SP_WITH_ERROR_CATCH:
   
   --(Wan02) - START
   SET @n_WarningNo = @n_LogWarningNo
   IF (XACT_STATE()) = -1 
   BEGIN
      SET @n_Continue = 3
   END
   --(Wan02) - END
   
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF @@TRANCOUNT > 0
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > 0
         BEGIN
            COMMIT TRAN
         END
      END

      IF @n_WarningNo < 1
      BEGIN  
         SET @n_WarningNo = 0
      END
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_WaveShip'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END
   END
   
   --(Wan02) - START
   SET @CUR_ERRLIST = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT   twl.TableName         
         ,  twl.SourceType        
         ,  twl.Refkey1           
         ,  twl.Refkey2           
         ,  twl.Refkey3           
         ,  twl.WriteType         
         ,  twl.LogWarningNo      
         ,  twl.ErrCode           
         ,  twl.Errmsg               
   FROM @t_WMSErrorList AS twl
   ORDER BY twl.RowID
   
   OPEN @CUR_ERRLIST
   
   FETCH NEXT FROM @CUR_ERRLIST INTO   @c_TableName         
                                     , @c_SourceType        
                                     , @c_Refkey1           
                                     , @c_Refkey2           
                                     , @c_Refkey3           
                                     , @c_WriteType         
                                     , @n_LogWarningNo      
                                     , @n_Err           
                                     , @c_Errmsg            
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      EXEC [WM].[lsp_WriteError_List] 
         @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
      ,  @c_TableName   = @c_TableName
      ,  @c_SourceType  = @c_SourceType
      ,  @c_Refkey1     = @c_Refkey1
      ,  @c_Refkey2     = @c_Refkey2
      ,  @c_Refkey3     = @c_Refkey3
      ,  @n_LogWarningNo= @n_LogWarningNo
      ,  @c_WriteType   = @c_WriteType
      ,  @n_err2        = @n_err 
      ,  @c_errmsg2     = @c_errmsg 
      ,  @b_Success     = @b_Success    
      ,  @n_err         = @n_err        
      ,  @c_errmsg      = @c_errmsg         
     
      FETCH NEXT FROM @CUR_ERRLIST INTO   @c_TableName         
                                        , @c_SourceType        
                                        , @c_Refkey1           
                                        , @c_Refkey2           
                                        , @c_Refkey3           
                                        , @c_WriteType         
                                        , @n_LogWarningNo      
                                        , @n_Err           
                                        , @c_Errmsg     
   END
   CLOSE @CUR_ERRLIST
   DEALLOCATE @CUR_ERRLIST
   --(Wan02) - END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END      
   REVERT
END

GO