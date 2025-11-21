SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: msp_mWaveReleaseWCS_Std                             */  
/* Creation Date: 2024-01-14                                             */  
/* Copyright: Maersk                                                     */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: Release to WCS                                               */  
/*                                                                       */  
/* Called By: mWMS Wave Release WCS                                      */  
/*                                                                       */  
/* Version: Maserk V2                                                    */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author  Ver   Purposes                                   */ 
/* 2024-01-14   Wan01   1.1   Initiase Created.                          */
/*                            UWP-13590-WMS to send the Order Include    */
/*                            message to WCS upon Wave release           */ 
/*                            UWP-13591-WMS to send the PTWWaveCheck     */
/*                            message to WCS upon Wave release           */ 
/* 2024-02-22   Wan02   1.2   UWP-13590-Fixed issue                      */
/* 2024-04-09   Wan03   1.3   UWP-12854-Order Include-ChilePuma          */
/* 2024-04-26   SSA01   1.4   UWP-12854-Partial Allocate Order Include - */
/*                                     ChilePuma                         */
/* 2024-09-26   SSA02   1.5   UWP-24265-Puma - Wave Release update       */
/*************************************************************************/   
CREATE   PROCEDURE [dbo].[msp_mWaveReleaseWCS_Std]      
  @c_Wavekey      NVARCHAR(10)  
 ,@b_Success      int        OUTPUT  
 ,@n_Err          int        OUTPUT  
 ,@c_Errmsg       NVARCHAR(250)  OUTPUT  
 AS  
 BEGIN  
    SET NOCOUNT ON   
    SET QUOTED_IDENTIFIER OFF   
    SET ANSI_NULLS OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF  
    
    DECLARE @n_Continue          INT          = 1    
          , @n_StartTCnt         INT          = @@TRANCOUNT       -- Holds the current transaction count  
          , @n_Debug             INT          = 0
          
          , @c_Facility          NVARCHAR(5)  = ''          
          , @c_Storerkey         NVARCHAR(15) = ''
          , @c_OrderKey          NVARCHAR(10) = ''
          , @c_OrderStatus       NVARCHAR(10) = '2'                                 --(Wan03)
          , @c_PartialOrderStatus       NVARCHAR(10) = '1'                          --(SSA01)
          , @b_RelWSWVCHKPTW     BIT          = 0                                   --(Wan03)
          
          , @c_TableName         NVARCHAR(30) = ''
          , @c_Key1              NVARCHAR(10) = ''
          , @c_Key2              NVARCHAR(30) = ''
          , @c_Key3              NVARCHAR(20) = ''
          , @c_TransmitBatch     NVARCHAR(30) = ''
      
          , @c_CfgWCS            NVARCHAR(10) = ''
          , @c_SPCode            NVARCHAR(30) = ''                                  --(Wan03)
          , @c_CfgWavRLWCSOpt5   NVARCHAR(4000)= ''                                 --(Wan03)
          , @c_RelOpenOrder      NVARCHAR(10)  = 'N'                                --(Wan03)
          , @c_SQL               NVARCHAR(1000)= ''                                 --(Wan03)
          , @c_SQLParms          NVARCHAR(1000)= ''                                 --(Wan03)
          , @c_ConditionQuery    NVARCHAR(1000)= ''                                 --(Wan03)
          , @c_EcomSingleFlag    NVARCHAR(1)= ''                                    --(SSA02)
          , @c_DocType           NVARCHAR(1)= 'N'                                   --(SSA02)
          , @cur_OPENORD         CURSOR

   IF OBJECT_ID('tempdb..#tORDERS') IS NOT NULL                                     --(Wan03) - START                             
   BEGIN
      DROP TABLE #tORDERS;
   END

   CREATE TABLE #tORDERS
      (  RowID          INT            NOT NULL IDENTITY(1,1)  PRIMARY KEY
      ,  Orderkey       NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  ECOM_SINGLE_Flag NVARCHAR(1)   NOT NULL DEFAULT('')                        --(SSA02)
      ,  DocType NVARCHAR(1)   NOT NULL DEFAULT('N')                                --(SSA02)
      )                                                                             --(Wan03) - END   

   SELECT TOP 1 
           @c_Facility  = o.Facility
         , @c_Storerkey = o.StorerKey
   FROM dbo.ORDERS AS o (NOLOCK)
   WHERE o.UserDefine09 = @c_Wavekey
   ORDER BY o.OrderKey DESC

   SELECT @c_CfgWCS = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'WCS')

   SELECT @c_SPCode = fsgr.Authority                                                --(Wan03) - START
         ,@c_CfgWavRLWCSOpt5  = fsgr.ConfigOption5
   FROM dbo.fnc_SelectGetRight(@c_Facility, @c_Storerkey, '', 'WaveReleaseToWCS_SP') AS fsgr
   
   IF @c_SPCode = '0' SET @c_SPCode = ''
   IF @c_SPCode NOT IN ('')
   BEGIN
      IF @c_CfgWavRLWCSOpt5 <> ''
      BEGIN
         SELECT @c_RelOpenOrder = dbo.fnc_GetParamValueFromString('@c_ReleaseOpenOrder',@c_CfgWavRLWCSOpt5,@c_RelOpenOrder)
         SELECT @c_ConditionQuery = dbo.fnc_GetParamValueFromString('@c_ConditionQuery',@c_CfgWavRLWCSOpt5,@c_ConditionQuery)
      END  

      IF @c_RelOpenOrder = 'Y'
      BEGIN
         SET @c_OrderStatus = '0'
         SET @c_PartialOrderStatus = '0'       --(SSA01)
      END
   END
    
   IF @c_CfgWCS = '1'
   BEGIN
      SET @c_SQL = N'SELECT ORD.OrderKey, ORD.ECOM_SINGLE_Flag, ORD.DocType'         --(SSA02)
                 + ' FROM dbo.WAVEDETAIL (NOLOCK)'
                 + ' JOIN ORDERS ORD (NOLOCK) ON ORD.OrderKey = WAVEDETAIL.OrderKey' --(SSA02)
                 + ' WHERE WAVEDETAIL.WaveKey = @c_Wavekey'
                 + ' AND ORD.[Status] IN (@c_OrderStatus,@c_PartialOrderStatus)'     --(SSA01)

      SET @c_SQL= @c_SQL + ' ' + @c_ConditionQuery + ' ORDER BY WAVEDETAIL.WaveDetailKey'

      SET @c_SQLParms = N'@c_Wavekey      NVARCHAR(10)'
                      + ',@c_OrderStatus  NVARCHAR(10)'
                      + ',@c_PartialOrderStatus  NVARCHAR(10)'         --(SSA01)

      INSERT INTO #tORDERS ( Orderkey, ECOM_SINGLE_Flag, DocType)      --(SSA02)
      EXEC sp_ExecuteSQL @c_SQL
                     ,@c_SQLParms
                     ,@c_Wavekey
                     ,@c_OrderStatus
                     ,@c_PartialOrderStatus                            --(SSA01)

      SET @cur_OPENORD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT o.Orderkey, o.ECOM_SINGLE_Flag, o.DocType                              --(SSA02)
      FROM #tORDERS o
      ORDER BY o.RowID                                                              --(Wan03) - END
         
      OPEN @cur_OPENORD
      
      FETCH NEXT FROM @cur_OPENORD INTO @c_OrderKey, @c_EcomSingleFlag, @c_DocType     --(SSA02)
      
      WHILE @@FETCH_STATUS <> -1 AND @n_Continue = 1
      BEGIN
        IF @c_EcomSingleFlag = 'M' AND @c_DocType = 'E'                                --(SSA02)
           BEGIN
             SET @c_TableName = 'WSORDCFM'                                              --(Wan02)
             SET @c_Key1 = @c_OrderKey
             SET @c_Key2 = @c_Wavekey
             SET @c_Key3 = @c_Storerkey                                                 --(wan02)

             EXEC dbo.ispGenTransmitLog2
                   @c_TableName   = @c_TableName
                ,  @c_Key1        = @c_Key1
                ,  @c_Key2        = @c_Key2
                ,  @c_Key3        = @c_Key3
                ,  @c_TransmitBatch = @c_TransmitBatch
                ,  @b_Success     = @b_Success
                ,  @n_err         = @n_err
                ,  @c_errmsg      = @c_errmsg

             IF @b_Success = 0
             BEGIN
                SET @n_Continue = 3
             END
             SET @b_RelWSWVCHKPTW = 1                                                   --(Wan03)
          END
         ----(SSA02) start ---
        ELSE
         BEGIN
            IF @n_Continue = 1 AND @c_DocType = 'N'
              BEGIN
                 SET @c_TableName = 'WSORDCFMlb'
                 SET @c_Key1 = @c_OrderKey
                 SET @c_Key2 = @c_Wavekey
                 SET @c_Key3 = @c_Storerkey

                 EXEC dbo.ispGenTransmitLog2
                       @c_TableName   = @c_TableName
                    ,  @c_Key1        = @c_Key1
                    ,  @c_Key2        = @c_Key2
                    ,  @c_Key3        = @c_Key3
                    ,  @c_TransmitBatch = @c_TransmitBatch
                    ,  @b_Success     = @b_Success
                    ,  @n_err         = @n_err
                    ,  @c_errmsg      = @c_errmsg

                 IF @b_Success = 0
                 BEGIN
                    SET @n_Continue = 3
                 END
              END
         END
         ----(SSA02) End--
         FETCH NEXT FROM @cur_OPENORD INTO @c_OrderKey, @c_EcomSingleFlag, @c_DocType      --(SSA02)
      END
      CLOSE @cur_OPENORD
      DEALLOCATE @cur_OPENORD
      
      IF @b_RelWSWVCHKPTW = 1 AND @n_Continue = 1                                   --(Wan03) 
      BEGIN
         SET @c_TableName = 'WSWVCHKPTW'                                            --(wan02)
         SET @c_Key1 = @c_Wavekey
         SET @c_Key2 = ''
         SET @c_Key3 = @c_Storerkey                                                 --(wan02)

         EXEC dbo.ispGenTransmitLog2
               @c_TableName   = @c_TableName
            ,  @c_Key1        = @c_Key1
            ,  @c_Key2        = @c_Key2
            ,  @c_Key3        = @c_Key3
            ,  @c_TransmitBatch = @c_TransmitBatch 
            ,  @b_Success     = @b_Success
            ,  @n_err         = @n_err
            ,  @c_errmsg      = @c_errmsg
         
         IF @b_Success = 0
         BEGIN
            SET @n_Continue = 3
         END
      END
   END    
EXIT_SP:
   IF OBJECT_ID('tempdb..#tORDERS') IS NOT NULL                                     --(Wan03) - START                             
   BEGIN
      DROP TABLE #tORDERS;
   END                                                                              --(Wan03) - END 

   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_Success = 0  
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTCnt  
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "msp_mWaveReleaseWCS_Std"  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    
      RETURN  
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END
END --sp end

GO