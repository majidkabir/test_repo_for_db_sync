SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  ispLPSPL03                                         */
/* Creation Date:  24-Jun-2022                                          */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose:  WMS-20063 - [MY] - SKECHERS - Build Load - Split Load Plan */
/*                                                                      */
/* Input Parameters:  @c_LoadKey                                        */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:  RMC Split Load Plan                                      */
/*                                                                      */
/* GitLab Version: 1.2                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver  Purposes                                   */
/* 24-Jun-2022 WLChooi  1.0  DevOps Combine Script                      */
/* 14-Jul-2022 WLChooi  1.1  Logic Fix - No need split if all PICK(WL01)*/
/* 15-Jun-2023 WLChooi  1.2  JSM-156769 Fix missing loadkey in BuildLoad*/
/*                           screen (WL02)                              */
/************************************************************************/
CREATE   PROC [dbo].[ispLPSPL03]
      @c_LoadKey NVARCHAR(10),
      @b_Success INT OUTPUT,
      @n_err     INT OUTPUT,
      @c_errmsg  NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_OrderKey            NVARCHAR( 10)
         , @c_Facility            NVARCHAR( 5)
         , @c_StorerKey           NVARCHAR( 15)
         , @n_continue            INT
         , @n_StartTranCnt        INT
         , @n_loadcount           INT
         , @n_NoOfGroupField      INT            
         , @c_LoadLineNumber      NVARCHAR(5)
         , @c_ToLoadkey           NVARCHAR(10)

 DECLARE @c_ListName             NVARCHAR(10)
       , @c_Code                 NVARCHAR(30)   -- e.g. LOC01
       , @c_Description          NVARCHAR(250)
       , @c_TableColumnName      NVARCHAR(250)  -- e.g. LOC.Floor
       , @c_TableName            NVARCHAR(30)
       , @c_ColumnName           NVARCHAR(30)
       , @c_ColumnType           NVARCHAR(10)
       , @c_SQLField             NVARCHAR(2000)
       , @c_SQLWhere             NVARCHAR(2000)
       , @c_SQLHaving            NVARCHAR(2000)
       , @c_SQLGroup             NVARCHAR(2000)
       , @c_SQLSort              NVARCHAR(2000)
       , @c_SQLDYN01             NVARCHAR(2000)
       , @c_SQLDYN02             NVARCHAR(2000)
       , @c_Field01              NVARCHAR(60)
       , @c_Field02              NVARCHAR(60)
       , @c_Field03              NVARCHAR(60)
       , @c_Field04              NVARCHAR(60)
       , @c_Field05              NVARCHAR(60)
       , @c_Field06              NVARCHAR(60)
       , @c_Field07              NVARCHAR(60)
       , @c_Field08              NVARCHAR(60)
       , @c_Field09              NVARCHAR(60)
       , @c_Field10              NVARCHAR(60)
       , @n_cnt                  INT
       , @c_OriTableColumnName   NVARCHAR(250)  -- e.g. LOC.Floor
       , @n_OrderCount           INT = 1
       , @c_ColValue             NVARCHAR(100)
       , @c_Option5              NVARCHAR(4000) = ''
       , @c_MaxOrderPerLoad      NVARCHAR(100) = '80'
       , @n_MaxOrderPerLoad      INT

   DECLARE @c_Batchno            NVARCHAR(10) = ''
         , @c_GetLoadkey         NVARCHAR(10)
         , @c_GetLocType         NVARCHAR(10)
         , @c_NewBatchno         NVARCHAR(10)
         , @n_TotalOrderCnt      INT
         , @n_TotalOrderQty      INT
         , @n_TotalLoadCnt       INT   --WL02

   CREATE TABLE #TMP_LocType (
      Loadkey   NVARCHAR(10),
      LocType   NVARCHAR(50)
   )

   SELECT @n_StartTranCnt = @@TRANCOUNT, @n_continue = 1, @n_loadcount = 0

   SELECT TOP 1 @c_Storerkey = ORDERS.Storerkey,
                @c_Facility  = ORDERS.Facility
   FROM ORDERS (NOLOCK)
   JOIN LOADPLANDETAIL (NOLOCK) ON LoadPlanDetail.OrderKey = ORDERS.OrderKey
   WHERE LOADPLANDETAIL.Loadkey = @c_Loadkey

   -------------------------- Validation ------------------------------
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS (SELECT 1
                 FROM PICKDETAIL PD (NOLOCK)
                 JOIN LOADPLANDETAIL LPD (NOLOCK) ON PD.OrderKey = LPD.OrderKey
                 WHERE LPD.LoadKey = @c_Loadkey
                 AND LEFT(TRIM(PD.PickSlipNo),1) = 'B')
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 61505
         SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Pickslipno is already generated, not allow to split. (ispLPSPL03)'
         GOTO RETURN_SP
      END
   END

   -------------------------- Construct Load Plan Dynamic Grouping ------------------------------
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SET @c_Listname = 'LOADSPLIT'
      
      IF (SELECT COUNT(1) FROM CODELKUP (NOLOCK) WHERE Listname = @c_ListName AND Storerkey = @c_Storerkey) = 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 61510
         SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Load Plan Split Condition Is Not Setup Yet. (Listname: LOADSPLIT) (ispLPSPL03)'
         GOTO RETURN_SP
      END     
   
      DECLARE CUR_CODELKUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT TOP 10 Code, Description, Long
         FROM   CODELKUP WITH (NOLOCK)
         WHERE  ListName = @c_ListName
         AND    Storerkey = @c_Storerkey
         ORDER BY Code
      
      OPEN CUR_CODELKUP
   
      FETCH NEXT FROM CUR_CODELKUP INTO @c_Code, @c_Description, @c_TableColumnName
   
      SELECT @c_SQLField = '', @c_SQLWhere = '', @c_SQLGroup = '', @n_cnt = 0, @c_SQLSort = '', @c_SQLHaving = ''
      WHILE @@FETCH_STATUS <> -1
      BEGIN
          SET @c_OriTableColumnName = @c_TableColumnName
          
          WHILE CHARINDEX('(', @c_TableColumnName) > 1
          BEGIN
             SET @c_TableColumnName = SUBSTRING(@c_TableColumnName, CHARINDEX('(', @c_TableColumnName) + 1, LEN(@c_TableColumnName) - CHARINDEX('(', @c_TableColumnName) - 1)
          END
          --SELECT @c_TableColumnName, LEN(@c_TableColumnName), CharIndex(')', @c_TableColumnName)
          WHILE CHARINDEX(')', @c_TableColumnName) > 1
          BEGIN
             SET @c_TableColumnName = SUBSTRING(@c_TableColumnName, 1, CHARINDEX(')', @c_TableColumnName) - 1)
          END
          
          SET @n_cnt = @n_cnt + 1
          SET @c_TableName = LEFT(@c_TableColumnName, CHARINDEX('.', @c_TableColumnName) - 1)
          SET @c_ColumnName = SUBSTRING(@c_TableColumnName,
                              CHARINDEX('.', @c_TableColumnName) + 1, LEN(@c_TableColumnName) - CHARINDEX('.', @c_TableColumnName))
          
          IF ISNULL(RTRIM(@c_TableName), '') NOT IN ('LOC', 'ORDERS')
          BEGIN
             SELECT @n_continue = 3
             SELECT @n_err = 61520
             SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Grouping Only Allow Refer To LOC Table''s Fields. Invalid Table: '+RTRIM(@c_TableColumnName)+' (ispLPSPL03)'
             GOTO RETURN_SP
          END
          
          SET @c_ColumnType = ''
          SELECT @c_ColumnType = DATA_TYPE
          FROM   INFORMATION_SCHEMA.COLUMNS
          WHERE  TABLE_NAME = @c_TableName
          AND    COLUMN_NAME = @c_ColumnName
          
          IF ISNULL(RTRIM(@c_ColumnType), '') = ''
          BEGIN
             SELECT @n_continue = 3
             SELECT @n_err = 61530
             SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Invalid Column Name: ' + RTRIM(@c_TableColumnName)+ '. (ispLPSPL03)'
             GOTO RETURN_SP
          END
          
          IF @c_ColumnType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint','text')
          BEGIN
             SELECT @n_continue = 3
             SELECT @n_err = 61540
             SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Numeric/Text Column Type Is Not Allowed For Load Plan Splitting: ' + RTRIM(@c_TableColumnName)+ '. (ispLPSPL03)'
             GOTO RETURN_SP
          END
          
          IF @c_ColumnType IN ('char', 'nvarchar', 'varchar')
          BEGIN
             SELECT @c_SQLField = @c_SQLField + ',' + RTRIM(@c_OriTableColumnName)
          
             IF @c_OriTableColumnName = @c_TableColumnName
             BEGIN
                SELECT @c_SQLWhere = @c_SQLWhere + ' AND ' + RTRIM(@c_OriTableColumnName) + '=' +
                       CASE WHEN @n_cnt = 1 THEN '@c_Field01'
                            WHEN @n_cnt = 2 THEN '@c_Field02'
                            WHEN @n_cnt = 3 THEN '@c_Field03'
                            WHEN @n_cnt = 4 THEN '@c_Field04'
                            WHEN @n_cnt = 5 THEN '@c_Field05'
                            WHEN @n_cnt = 6 THEN '@c_Field06'
                            WHEN @n_cnt = 7 THEN '@c_Field07'
                            WHEN @n_cnt = 8 THEN '@c_Field08'
                            WHEN @n_cnt = 9 THEN '@c_Field09'
                            WHEN @n_cnt = 10 THEN '@c_Field10' END
             END
             ELSE
             BEGIN
                SELECT @c_SQLHaving = @c_SQLHaving + ' AND ' + RTRIM(@c_OriTableColumnName) + '=' +
                       CASE WHEN @n_cnt = 1 THEN '@c_Field01'
                            WHEN @n_cnt = 2 THEN '@c_Field02'
                            WHEN @n_cnt = 3 THEN '@c_Field03'
                            WHEN @n_cnt = 4 THEN '@c_Field04'
                            WHEN @n_cnt = 5 THEN '@c_Field05'
                            WHEN @n_cnt = 6 THEN '@c_Field06'
                            WHEN @n_cnt = 7 THEN '@c_Field07'
                            WHEN @n_cnt = 8 THEN '@c_Field08'
                            WHEN @n_cnt = 9 THEN '@c_Field09'
                            WHEN @n_cnt = 10 THEN '@c_Field10' END
             END
          END
          
          IF @c_ColumnType IN ('datetime')
          BEGIN
             SELECT @c_SQLField = @c_SQLField + ', CONVERT(VARCHAR(10),' + RTRIM(@c_OriTableColumnName) + ',112)'
             SELECT @c_SQLWhere = @c_SQLWhere + ' AND CONVERT(VARCHAR(10),' + RTRIM(@c_OriTableColumnName) + ',112)=' +
                    CASE WHEN @n_cnt = 1 THEN  '@c_Field01'
                         WHEN @n_cnt = 2 THEN  '@c_Field02'
                         WHEN @n_cnt = 3 THEN  '@c_Field03'
                         WHEN @n_cnt = 4 THEN  '@c_Field04'
                         WHEN @n_cnt = 5 THEN  '@c_Field05'
                         WHEN @n_cnt = 6 THEN  '@c_Field06'
                         WHEN @n_cnt = 7 THEN  '@c_Field07'
                         WHEN @n_cnt = 8 THEN  '@c_Field08'
                         WHEN @n_cnt = 9 THEN  '@c_Field09'
                         WHEN @n_cnt = 10 THEN '@c_Field10' END
          END
   
         FETCH NEXT FROM CUR_CODELKUP INTO @c_Code, @c_Description, @c_TableColumnName
      END
      CLOSE CUR_CODELKUP
      DEALLOCATE CUR_CODELKUP

      SELECT @n_NoOfGroupField = @n_cnt 
      
      SELECT @c_SQLSort = @c_SQLField
      
      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT LTRIM(RTRIM(ColValue)) FROM dbo.fnc_delimsplit (',', @c_SQLField) 
      WHERE LTRIM(RTRIM(ColValue)) <> ''
      
      OPEN CUR_LOOP
      
      FETCH NEXT FROM CUR_LOOP INTO @c_ColValue
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF CHARINDEX('(',@c_ColValue) = 0 AND CHARINDEX(')',@c_ColValue) = 0
         BEGIN
            SET @c_SQLGroup = @c_SQLGroup + ', ' + @c_ColValue
         END
      
         FETCH NEXT FROM CUR_LOOP INTO @c_ColValue
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
      
      --SELECT @c_SQLGroup
      
      WHILE @n_cnt < 10
      BEGIN
         SET @n_cnt = @n_cnt + 1
         SELECT @c_SQLField = @c_SQLField + ','''''
      
         SELECT @c_SQLWhere = @c_SQLWhere + ' AND ''''=' +
                CASE WHEN @n_cnt = 1 THEN  'ISNULL(@c_Field01,'''')'
                     WHEN @n_cnt = 2 THEN  'ISNULL(@c_Field02,'''')'
                     WHEN @n_cnt = 3 THEN  'ISNULL(@c_Field03,'''')'
                     WHEN @n_cnt = 4 THEN  'ISNULL(@c_Field04,'''')'
                     WHEN @n_cnt = 5 THEN  'ISNULL(@c_Field05,'''')'
                     WHEN @n_cnt = 6 THEN  'ISNULL(@c_Field06,'''')'
                     WHEN @n_cnt = 7 THEN  'ISNULL(@c_Field07,'''')'
                     WHEN @n_cnt = 8 THEN  'ISNULL(@c_Field08,'''')'
                     WHEN @n_cnt = 9 THEN  'ISNULL(@c_Field09,'''')'
                     WHEN @n_cnt = 10 THEN 'ISNULL(@c_Field10,'''')' 
                END
      END
   END --select @c_SQLField, @c_SQLGroup, @c_SQLWhere, @c_Field01
   --BEGIN TRAN

   --WL01 S
   -------------------------- PreValidation ------------------------------
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_SQLDYN01 = 'DECLARE cur_PreVal CURSOR FAST_FORWARD READ_ONLY FOR ' + CHAR(13) + 
         + ' SELECT ORDERS.Storerkey ' + REPLACE(@c_SQLField,',ORDERS.Orderkey',',''''') + CHAR(13) + 
         + ' FROM ORDERS WITH (NOLOCK) '
         + ' JOIN LoadPlanDetail LD WITH (NOLOCK) ON (ORDERS.OrderKey = LD.OrderKey) '  + CHAR(13) + 
         + ' JOIN PICKDETAIL PD WITH (NOLOCK) ON (PD.Orderkey = ORDERS.Orderkey) '  + CHAR(13) + 
         + ' JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) '  + CHAR(13) + 
         + ' WHERE LD.LoadKey = ''' +  RTRIM(@c_LoadKey) +''''  + CHAR(13) + 
         + ' GROUP BY ORDERS.Storerkey ' + REPLACE(@c_SQLGroup,', ORDERS.Orderkey','')  + CHAR(13) + 
         + ' ORDER BY ORDERS.Storerkey ' + REPLACE(@c_SQLSort,',ORDERS.Orderkey','')

      EXEC (@c_SQLDYN01)

      OPEN cur_PreVal
      
      FETCH NEXT FROM cur_PreVal INTO @c_Storerkey, @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05,
                                      @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10
                                       
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN
         --No Group Orderkey, whole Load All is Pick, no need to split
         IF (@c_Field01 = @c_Field02) AND @c_Field02 = 'PICK' AND @c_Field03 = '2'
         BEGIN
            GOTO RETURN_SP
         END

         FETCH NEXT FROM cur_PreVal INTO @c_Storerkey, @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05,
                                         @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10               
      END
      CLOSE cur_PreVal
      DEALLOCATE cur_PreVal
   END
   --WL01 E
   
   -------------------------- SPLIT LOAD PLAN ------------------------------
   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_SQLDYN01 = 'DECLARE cur_LPSplit CURSOR FAST_FORWARD READ_ONLY FOR ' + CHAR(13) + 
      + ' SELECT ORDERS.Storerkey ' + @c_SQLField  + CHAR(13) + 
      + ' FROM ORDERS WITH (NOLOCK) '
      + ' JOIN LoadPlanDetail LD WITH (NOLOCK) ON (ORDERS.OrderKey = LD.OrderKey) '  + CHAR(13) + 
      + ' JOIN PICKDETAIL PD WITH (NOLOCK) ON (PD.Orderkey = ORDERS.Orderkey) '  + CHAR(13) + 
      + ' JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) '  + CHAR(13) + 
      + ' WHERE LD.LoadKey = ''' +  RTRIM(@c_LoadKey) +''''  + CHAR(13) + 
      + ' GROUP BY ORDERS.Storerkey ' + @c_SQLGroup  + CHAR(13) + 
      + ' ORDER BY ORDERS.Storerkey ' + @c_SQLSort

      EXEC (@c_SQLDYN01)--PRINT @c_SQLDYN01
   
      OPEN cur_LPSplit
      
      FETCH NEXT FROM cur_LPSplit INTO @c_Storerkey, @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05,
                                       @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10
                                       
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN
         --Non purely pick will be remain in current Load
         --Purely pick will move to new Load

         --If MIN(LocationType) = MAX(LocationType) AND @c_Field01/@c_Field02 = PICK, pure PICK
         IF (@c_Field01 = @c_Field02) AND @c_Field02 = 'PICK' AND @c_Field03 = '2'
         BEGIN
            SELECT @c_ToLoadkey = TLT.Loadkey
            FROM #TMP_LocType TLT
            WHERE TLT.LocType = 'PICK'

            IF ISNULL(@c_ToLoadkey,'') = ''
            BEGIN
               SET @c_ToLoadkey = '' --every group split to new loadkey
               SELECT @n_loadcount = @n_loadcount + 1
               SET @n_OrderCount = 1
            END
         END
         ELSE
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM #TMP_LocType WHERE Loadkey = @c_Loadkey AND LocType = 'NONPICK')
            BEGIN
               INSERT INTO #TMP_LocType
               SELECT @c_Loadkey, 'NONPICK'
            END

            GOTO NEXT_LOOP
         END

         SELECT @c_SQLDYN02 = 'DECLARE cur_loadplansp CURSOR FAST_FORWARD READ_ONLY FOR ' + CHAR(13) + 
         + ' SELECT ORDERS.OrderKey, LD.LoadLineNumber '
         + ' FROM ORDERS WITH (NOLOCK) '
         + ' JOIN LOADPLANDETAIL LD WITH (NOLOCK) ON (ORDERS.OrderKey = LD.OrderKey) '
         + ' JOIN PICKDETAIL PD WITH (NOLOCK) ON (PD.Orderkey = ORDERS.Orderkey) '
         + ' JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) '
         + ' WHERE ORDERS.StorerKey = @c_StorerKey ' +
         + ' AND LD.Loadkey = @c_LoadKey '
         + ' AND ORDERS.Status = ''2'' '
         + CASE WHEN @c_SQLWhere <> '' THEN @c_SQLWhere ELSE '' END
         + ' GROUP BY ORDERS.OrderKey, LD.LoadLineNumber '
         + CASE WHEN @c_SQLHaving <> '' THEN 'HAVING 1=1 ' + @c_SQLHaving ELSE '' END
         + ' ORDER BY ORDERS.OrderKey '

        EXEC sp_executesql @c_SQLDYN02, 
             N'@c_Storerkey NVARCHAR(15), @c_Loadkey NVARCHAR(10), @c_Field01 NVARCHAR(60),
               @c_Field02 NVARCHAR(60),@c_Field03 NVARCHAR(60),@c_Field04 NVARCHAR(60),
               @c_Field05 NVARCHAR(60), @c_Field06 NVARCHAR(60), @c_Field07 NVARCHAR(60),
               @c_Field08 NVARCHAR(60), @c_Field09 NVARCHAR(60), @c_Field10 NVARCHAR(60)',
             @c_Storerkey,
             @c_Loadkey,
             @c_Field01,
             @c_Field02,
             @c_Field03,
             @c_Field04,
             @c_Field05,
             @c_Field06,
             @c_Field07,
             @c_Field08,
             @c_Field09,
             @c_Field10
   
         OPEN cur_loadplansp
   
         FETCH NEXT FROM cur_loadplansp INTO @c_OrderKey, @c_LoadLineNumber
         
         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
         BEGIN  --PRINT @c_SQLDYN02--PRINT @c_OrderKey + ' ' + @c_LoadLineNumber + ' ' + CAST(@n_MaxOrderPerLoad AS NVARCHAR(10)) + ' ' + @c_ToLoadkey
            EXEC isp_MoveOrderToLoad
             @c_LoadKey        
            ,@c_LoadlineNumber 
            ,@c_ToLoadkey       OUTPUT  
            ,@b_success         OUTPUT
            ,@n_err             OUTPUT
            ,@c_errmsg          OUTPUT    
   
            IF @b_success <> 1  
            BEGIN
                SELECT @n_continue = 3
                SELECT @n_err = 61550
                SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Move Load Plan Order Failed. (ispLPSPL03)'
            END              
            
            IF NOT EXISTS (SELECT 1 FROM #TMP_LocType WHERE Loadkey = @c_ToLoadkey AND LocType = 'PICK')
            BEGIN
               INSERT INTO #TMP_LocType
               SELECT @c_ToLoadkey, 'PICK'
            END                                   
            
            IF @n_OrderCount = @n_MaxOrderPerLoad AND @n_MaxOrderPerLoad > 0
            BEGIN
               SET @n_OrderCount = 1
               SELECT @n_loadcount = @n_loadcount + 1
   
               UPDATE LOADPLAN WITH (ROWLOCK)                 
               SET LOADPLAN.TruckSize                = OL.TruckSize               
                  --,LOADPLAN.[Status]               = OL.[Status]                          
                  ,LOADPLAN.SuperOrderFlag           = OL.SuperOrderFlag          
                  ,LOADPLAN.SectionKey               = OL.SectionKey              
                  ,LOADPLAN.CarrierKey               = OL.CarrierKey              
                  ,LOADPLAN.[Route]                  = OL.[Route]                 
                  ,LOADPLAN.TrfRoom                  = OL.TrfRoom                 
                  ,LOADPLAN.DummyRoute               = OL.DummyRoute              
                  ,LOADPLAN.MBOLKey                  = OL.MBOLKey                 
                  ,LOADPLAN.facility                 = OL.facility                
                  ,LOADPLAN.PROCESSFLAG              = OL.PROCESSFLAG             
                  ,LOADPLAN.Vehicle_Type             = OL.Vehicle_Type            
                  ,LOADPLAN.Driver                   = OL.Driver                  
                  ,LOADPLAN.Delivery_Zone            = OL.Delivery_Zone           
                  ,LOADPLAN.Truck_Type               = OL.Truck_Type              
                  ,LOADPLAN.Load_Userdef1            = OL.Load_Userdef1           
                  ,LOADPLAN.Load_Userdef2            = OL.Load_Userdef2           
                  ,LOADPLAN.lpuserdefdate01          = OL.lpuserdefdate01         
                  ,LOADPLAN.FinalizeFlag             = OL.FinalizeFlag            
                  ,LOADPLAN.UserDefine01             = OL.UserDefine01   --WL02            
                  ,LOADPLAN.UserDefine02             = OL.UserDefine02   --WL02            
                  ,LOADPLAN.UserDefine03             = OL.UserDefine03   --WL02            
                  ,LOADPLAN.UserDefine04             = OL.UserDefine04   --WL02            
                  ,LOADPLAN.UserDefine05             = OL.UserDefine05   --WL02            
                  ,LOADPLAN.UserDefine06             = OL.UserDefine06   --WL02            
                  ,LOADPLAN.UserDefine07             = OL.UserDefine07   --WL02            
                  ,LOADPLAN.UserDefine08             = OL.UserDefine08   --WL02            
                  ,LOADPLAN.UserDefine09             = OL.UserDefine09   --WL02            
                  ,LOADPLAN.UserDefine10             = OL.UserDefine10   --WL02   
                  ,LOADPLAN.ExternLoadKey            = @c_Loadkey
                  ,LOADPLAN.Priority                 = OL.Priority                
                  ,LOADPLAN.DispatchPalletPickMethod = OL.DispatchPalletPickMethod
                  ,LOADPLAN.DispatchCasePickMethod   = OL.DispatchCasePickMethod  
                  ,LOADPLAN.DispatchPiecePickMethod  = OL.DispatchPiecePickMethod 
                  ,LOADPLAN.LoadPickMethod           = OL.LoadPickMethod          
                  ,LOADPLAN.MBOLGroupMethod          = OL.MBOLGroupMethod         
                  ,LOADPLAN.DefaultStrategykey       = OL.DefaultStrategykey      
                  ,LOADPLAN.OTM_DispatchDate         = OL.OTM_DispatchDate        
                  ,LOADPLAN.TrafficCop               = NULL
               FROM LOADPLAN 
               JOIN LOADPLAN OL (NOLOCK) ON OL.Loadkey = @c_Loadkey
               WHERE LOADPLAN.Loadkey = @c_ToLoadKey
              
               SET @n_err = @@ERROR
               IF @n_err <> 0  
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 61560
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update LOADPLAN Table Failed. (ispLPSPL03)'
               END
   
               UPDATE LOADPLANDETAIL WITH (ROWLOCK)                 
               SET LOADPLANDETAIL.ExternLoadKey = @c_Loadkey
               WHERE LOADPLANDETAIL.Loadkey = @c_ToLoadKey
              
               SET @n_err = @@ERROR
               IF @n_err <> 0  
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 61561
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update LOADPLANDETAIL Table Failed. (ispLPSPL03)'
               END
   
               SET @c_ToLoadKey = ''
            END
            ELSE
            BEGIN
               SET @n_OrderCount = @n_OrderCount + 1
            END
            
            FETCH NEXT FROM cur_loadplansp INTO @c_OrderKey, @c_LoadLineNumber
         END
         CLOSE cur_loadplansp
         DEALLOCATE cur_loadplansp                 
                  
         UPDATE LOADPLAN WITH (ROWLOCK)                 
          SET LOADPLAN.TruckSize                = OL.TruckSize               
            --,LOADPLAN.[Status]                 = OL.[Status]                          
             ,LOADPLAN.SuperOrderFlag           = OL.SuperOrderFlag          
             ,LOADPLAN.SectionKey               = OL.SectionKey              
             ,LOADPLAN.CarrierKey               = OL.CarrierKey              
             ,LOADPLAN.[Route]                  = OL.[Route]                 
             ,LOADPLAN.TrfRoom                  = OL.TrfRoom                 
             ,LOADPLAN.DummyRoute               = OL.DummyRoute              
             ,LOADPLAN.MBOLKey                  = OL.MBOLKey                 
             ,LOADPLAN.facility                 = OL.facility                
             ,LOADPLAN.PROCESSFLAG              = OL.PROCESSFLAG             
             ,LOADPLAN.Vehicle_Type             = OL.Vehicle_Type            
             ,LOADPLAN.Driver                   = OL.Driver                  
             ,LOADPLAN.Delivery_Zone            = OL.Delivery_Zone           
             ,LOADPLAN.Truck_Type               = OL.Truck_Type              
             ,LOADPLAN.Load_Userdef1            = OL.Load_Userdef1           
             ,LOADPLAN.Load_Userdef2            = OL.Load_Userdef2           
             ,LOADPLAN.lpuserdefdate01          = OL.lpuserdefdate01         
             ,LOADPLAN.FinalizeFlag             = OL.FinalizeFlag            
             ,LOADPLAN.UserDefine01             = OL.UserDefine01   --WL02            
             ,LOADPLAN.UserDefine02             = OL.UserDefine02   --WL02            
             ,LOADPLAN.UserDefine03             = OL.UserDefine03   --WL02            
             ,LOADPLAN.UserDefine04             = OL.UserDefine04   --WL02            
             ,LOADPLAN.UserDefine05             = OL.UserDefine05   --WL02            
             ,LOADPLAN.UserDefine06             = OL.UserDefine06   --WL02            
             ,LOADPLAN.UserDefine07             = OL.UserDefine07   --WL02            
             ,LOADPLAN.UserDefine08             = OL.UserDefine08   --WL02            
             ,LOADPLAN.UserDefine09             = OL.UserDefine09   --WL02            
             ,LOADPLAN.UserDefine10             = OL.UserDefine10   --WL02   
             ,LOADPLAN.ExternLoadKey            = @c_Loadkey
             ,LOADPLAN.Priority                 = OL.Priority                
             ,LOADPLAN.DispatchPalletPickMethod = OL.DispatchPalletPickMethod
             ,LOADPLAN.DispatchCasePickMethod   = OL.DispatchCasePickMethod  
             ,LOADPLAN.DispatchPiecePickMethod  = OL.DispatchPiecePickMethod 
             ,LOADPLAN.LoadPickMethod           = OL.LoadPickMethod          
             ,LOADPLAN.MBOLGroupMethod          = OL.MBOLGroupMethod         
             ,LOADPLAN.DefaultStrategykey       = OL.DefaultStrategykey      
             ,LOADPLAN.OTM_DispatchDate         = OL.OTM_DispatchDate        
             ,LOADPLAN.TrafficCop               = NULL
         FROM LOADPLAN 
         JOIN LOADPLAN OL (NOLOCK) ON OL.Loadkey = @c_Loadkey
         WHERE LOADPLAN.Loadkey = @c_ToLoadKey
   
         SET @n_err = @@ERROR
         IF @n_err <> 0  
         BEGIN
             SELECT @n_continue = 3
             SELECT @n_err = 61560
             SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Update LOADPLAN Table Failed. (ispLPSPL03)'
         END 
         
         UPDATE LOADPLANDETAIL WITH (ROWLOCK)                 
         SET LOADPLANDETAIL.ExternLoadKey = @c_Loadkey
         WHERE LOADPLANDETAIL.Loadkey = @c_ToLoadKey
              
         SET @n_err = @@ERROR
         IF @n_err <> 0  
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 61561
            SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Update LOADPLANDETAIL Table Failed. (ispLPSPL03)'
         END                   

         NEXT_LOOP:
   
         FETCH NEXT FROM cur_LPSplit INTO @c_Storerkey, @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05,
                         @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10
      END
      CLOSE cur_LPSplit
      DEALLOCATE cur_LPSplit
   END

   --WL01 S
   --IF @n_continue = 1 OR @n_continue = 2
   --BEGIN
   --   IF @n_loadcount > 0
   --      SELECT @c_errmsg = RTRIM(CAST(@n_loadcount AS CHAR)) + ' New Load Plan Generated'
   --   ELSE
   --      SELECT @c_errmsg = 'No New Load Plan Generated'
   --END
   --WL01 E

   --Update BuildLoadLog and BuildLoadDetailLog table
   IF (@n_continue = 1 OR @n_continue = 2) AND EXISTS (SELECT 1 FROM #TMP_LocType TLT WHERE TLT.LocType = 'PICK')
   BEGIN 
      --WL02 S
      --Get Batchno for parent Loadkey
      SELECT @c_Batchno = BatchNo
      FROM BuildLoadDetailLog (NOLOCK)
      WHERE Loadkey = @c_LoadKey AND Storerkey = @c_Storerkey

      --Save BuildLoadDetailLog for parent Loadkey
      SELECT TOP 1
             Storerkey, Loadkey, Duration, TotalOrderCnt, TotalOrderQty,
             UDF01, UDF02, UDF03, UDF04, UDF05,
             Addwho, Adddate, EditWho, EditDate
      INTO #TMP_BuildLoadDetailLog
      FROM BuildLoadDetailLog (NOLOCK)
      WHERE BatchNo = @c_Batchno 
      AND Storerkey = @c_Storerkey
      AND Loadkey = @c_Loadkey

      --Delete Parent Load from BuildLoadDetailLog table
      DELETE FROM BuildLoadDetailLog
      WHERE BatchNo = @c_Batchno 
      AND Storerkey = @c_Storerkey
      AND Loadkey = @c_Loadkey

      --Get TotalLoadCnt for current BatchNo after removing parent load
      SELECT @n_TotalLoadCnt = COUNT(DISTINCT Loadkey)
      FROM BuildLoadDetailLog (NOLOCK)
      WHERE BatchNo = @c_Batchno 
      AND Storerkey = @c_Storerkey

      UPDATE BuildLoadLog WITH (ROWLOCK)
      SET TotalLoadCnt = @n_TotalLoadCnt
        , UDF05 = 'ispLPSPL03'
      WHERE BatchNo = @c_Batchno 
      AND Storerkey = @c_Storerkey 

      --Store Parent BuildLoadLog and BuildLoadDetailLog Load Info into temp table
      /*
      SELECT Facility, Storerkey, BuildParmGroup, BuildParmCode, BuildParmString, Duration, TotalLoadCnt,
             UDF01, UDF02, UDF03, UDF04, UDF05, [Status],
             Addwho, Adddate, EditWho, EditDate
      INTO #TMP_BuildLoadLog
      FROM BuildLoadLog (NOLOCK) 
      WHERE BatchNo = @c_Batchno

      SELECT TOP 1
             Storerkey, Loadkey, Duration, TotalOrderCnt, TotalOrderQty,
             UDF01, UDF02, UDF03, UDF04, UDF05,
             Addwho, Adddate, EditWho, EditDate
      INTO #TMP_BuildLoadDetailLog
      FROM BuildLoadDetailLog (NOLOCK)
      WHERE BatchNo = @c_Batchno
      
      --Delete Parent Load from BuildLoadLog and BuildLoadDetailLog table
      DELETE FROM BuildLoadDetailLog
      WHERE BatchNo = @c_Batchno AND Storerkey = @c_Storerkey

      SET @n_err = @@ERROR
      IF @n_err <> 0  
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 61564
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete BuildLoadDetailLog Table Failed. (ispLPSPL03)'
      END    

      DELETE FROM BuildLoadLog
      WHERE BatchNo = @c_Batchno AND Storerkey = @c_Storerkey

      SET @n_err = @@ERROR
      IF @n_err <> 0  
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 61565
         SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Delete BuildLoadLog Table Failed. (ispLPSPL03)'
      END*/
      --WL02 E

      DECLARE CUR_LocType CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT Loadkey, LocType
      FROM #TMP_LocType

      OPEN CUR_LocType

      FETCH NEXT FROM CUR_LocType INTO @c_GetLoadkey, @c_GetLocType

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         --1 Load 1 BatchNo
         SET @c_NewBatchno = ''   --WL02

         --For new load - need to insert BuildLoadLog
         IF @c_GetLocType = 'PICK'   --WL02
         BEGIN
            INSERT INTO BuildLoadLog (Facility, Storerkey, BuildParmGroup, BuildParmCode, BuildParmString, Duration, TotalLoadCnt,
                                      UDF01, UDF02, UDF03, UDF04, UDF05, Status,
                                      Addwho, Adddate, EditWho, EditDate)
            SELECT TOP 1   --WL02
                   Facility, Storerkey, BuildParmGroup, BuildParmCode,
                   BuildParmString, Duration, 1,   --WL02
                   UDF01, UDF02, UDF03, UDF04, 
                   'ispLPSPL03_PICK',   --WL02 
                   [Status],
                   Addwho, Adddate, EditWho, EditDate
            FROM BuildLoadLog (NOLOCK)     --WL02
            WHERE BatchNo = @c_Batchno     --WL02
            AND Storerkey = @c_Storerkey   --WL02

            SELECT @c_NewBatchno = SCOPE_IDENTITY()

            SET @n_err = @@ERROR
            IF @n_err <> 0  
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61562
               SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': INSERT BuildLoadLog Table Failed. (ispLPSPL03)'
            END   
         END

         --WL02 S
         IF @c_NewBatchno = ''
         BEGIN
            SET @c_NewBatchno = @c_Batchno
         END
         --WL02 E

         SELECT @n_TotalOrderCnt = OrderCnt
         FROM Loadplan (NOLOCK)
         WHERE Loadkey = @c_GetLoadkey

         SELECT @n_TotalOrderQty = SUM(OH.OpenQty)
         FROM ORDERS OH (NOLOCK)
         JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.Orderkey = OH.Orderkey
         WHERE LPD.LoadKey = @c_GetLoadkey

         INSERT INTO BuildLoadDetailLog (BatchNo,
                                         Storerkey, Loadkey, Duration, TotalOrderCnt, TotalOrderQty,
                                         UDF01, UDF02, UDF03, UDF04, UDF05,
                                         Addwho, Adddate, EditWho, EditDate )
         SELECT @c_NewBatchno,
                Storerkey, @c_GetLoadkey, Duration,
                @n_TotalOrderCnt, @n_TotalOrderQty,
                UDF01, UDF02, UDF03, UDF04, 
                CASE WHEN @c_GetLocType = 'PICK' THEN 'ispLPSPL03_PICK' ELSE 'ispLPSPL03' END,
                Addwho, Adddate, EditWho, EditDate
         FROM #TMP_BuildLoadDetailLog (NOLOCK) 

         SET @n_err = @@ERROR
         IF @n_err <> 0  
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 61563
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT BuildLoadDetailLog Table Failed. (ispLPSPL03)'
         END  

         FETCH NEXT FROM CUR_LocType INTO @c_GetLoadkey, @c_GetLocType
      END
      CLOSE CUR_LocType
      DEALLOCATE CUR_LocType
   END
   
RETURN_SP:
   --WL01 S
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @n_loadcount > 0 AND ISNULL(@c_errmsg,'') = ''
      BEGIN
         SELECT @c_errmsg = RTRIM(CAST(@n_loadcount AS CHAR)) + ' New Load Plan Generated'
      END
      IF @n_loadcount > 0 AND ISNULL(@c_errmsg,'') <> ''
      BEGIN
         SELECT @c_errmsg = RTRIM(CAST(@n_loadcount AS CHAR)) + ' New Load Plan Generated with error: ' 
                          + @c_errmsg
      END
      ELSE
      BEGIN
         IF ISNULL(@c_errmsg,'') = ''
         BEGIN
            SELECT @c_errmsg = 'No New Load Plan Generated'
         END
         ELSE
         BEGIN
            SELECT @c_errmsg = 'No New Load Plan Generated. Error: '
                             + @c_errmsg
         END
      END
   END

   IF CURSOR_STATUS('GLOBAL', 'cur_PreVal') IN (0 , 1)
   BEGIN
      CLOSE cur_PreVal
      DEALLOCATE cur_PreVal   
   END

   IF CURSOR_STATUS('GLOBAL', 'cur_LPSplit') IN (0 , 1)
   BEGIN
      CLOSE cur_LPSplit
      DEALLOCATE cur_LPSplit   
   END

   IF CURSOR_STATUS('GLOBAL', 'cur_loadplansp') IN (0 , 1)
   BEGIN
      CLOSE cur_loadplansp
      DEALLOCATE cur_loadplansp   
   END
   --WL01 E
   
   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_LocType') IN (0 , 1)
   BEGIN
      CLOSE CUR_LocType
      DEALLOCATE CUR_LocType   
   END

   IF OBJECT_ID('tempdb..#TMP_BuildLoadDetailLog') IS NOT NULL
      DROP TABLE #TMP_BuildLoadDetailLog

   IF OBJECT_ID('tempdb..#TMP_BuildLoadLog') IS NOT NULL
      DROP TABLE #TMP_BuildLoadLog

   --WL02
   IF OBJECT_ID('tempdb..#TMP_LocType') IS NOT NULL  
      DROP TABLE #TMP_LocType

   IF @n_continue=3 -- Error Occured - Process And Return
   BEGIN
       SELECT @b_success = 0
       IF @@TRANCOUNT=1
          AND @@TRANCOUNT>@n_StartTranCnt
       BEGIN
           ROLLBACK TRAN
       END
       ELSE
       BEGIN
           WHILE @@TRANCOUNT>@n_StartTranCnt
           BEGIN
               COMMIT TRAN
           END
       END
       EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispLPSPL03'
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
       RETURN
   END
   ELSE
   BEGIN
       SELECT @b_success = 1
       WHILE @@TRANCOUNT>@n_StartTranCnt
       BEGIN
           COMMIT TRAN
       END
       RETURN
   END
END

GO