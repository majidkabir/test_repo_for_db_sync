SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  ispLPSPL02                                         */
/* Creation Date:  13-Jul-2020                                          */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose:  WMS-14212 - JP_HM_SplitLoadByFloor                         */
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
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver  Purposes                                   */
/* 2020-08-26  WLChooi  1.1  WMS-14845 - Show Child Load in BuidLoad    */
/*                           Screen and Delete Parent Load (WL01)       */
/************************************************************************/
CREATE PROC [dbo].[ispLPSPL02]
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

   DECLARE  @c_OrderKey            NVARCHAR( 10)
           ,@c_Facility            NVARCHAR( 5)
           ,@c_StorerKey           NVARCHAR( 15)
           ,@n_continue            INT
           ,@n_StartTranCnt        INT
           ,@n_loadcount           INT
           ,@n_NoOfGroupField      INT            
           ,@c_LoadLineNumber      NVARCHAR(5)
           ,@c_ToLoadkey           NVARCHAR(10)

 DECLARE @c_ListName              NVARCHAR(10)
         ,@c_Code                 NVARCHAR(30)   -- e.g. LOC01
         ,@c_Description          NVARCHAR(250)
         ,@c_TableColumnName      NVARCHAR(250)  -- e.g. LOC.Floor
         ,@c_TableName            NVARCHAR(30)
         ,@c_ColumnName           NVARCHAR(30)
         ,@c_ColumnType           NVARCHAR(10)
         ,@c_SQLField             NVARCHAR(2000)
         ,@c_SQLWhere             NVARCHAR(2000)
         ,@c_SQLHaving            NVARCHAR(2000)
         ,@c_SQLGroup             NVARCHAR(2000)
         ,@c_SQLSort              NVARCHAR(2000)
         ,@c_SQLDYN01             NVARCHAR(2000)
         ,@c_SQLDYN02             NVARCHAR(2000)
         ,@c_Field01              NVARCHAR(60)
         ,@c_Field02              NVARCHAR(60)
         ,@c_Field03              NVARCHAR(60)
         ,@c_Field04              NVARCHAR(60)
         ,@c_Field05              NVARCHAR(60)
         ,@c_Field06              NVARCHAR(60)
         ,@c_Field07              NVARCHAR(60)
         ,@c_Field08              NVARCHAR(60)
         ,@c_Field09              NVARCHAR(60)
         ,@c_Field10              NVARCHAR(60)
         ,@n_cnt                  INT
         ,@c_OriTableColumnName   NVARCHAR(250)  -- e.g. LOC.Floor
         ,@n_OrderCount           INT = 1
         ,@c_ColValue             NVARCHAR(100)
         ,@c_Option5              NVARCHAR(4000) = ''
         ,@c_MaxOrderPerLoad      NVARCHAR(100) = '80'
         ,@n_MaxOrderPerLoad      INT
         ,@c_CurrentMaxFloor      NVARCHAR(100)
         ,@c_PrevMaxFloor         NVARCHAR(100)
         ,@c_Userdefine04         NVARCHAR(20)

   --WL01 START
   CREATE TABLE #TMP_FLOOR (
      Loadkey   NVARCHAR(10),
      [Floor]   NVARCHAR(10)
   )
   --WL01 END

   SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue = 1, @n_loadcount = 0

   SELECT TOP 1 @c_Storerkey = Storerkey,
                @c_Facility = Facility
   FROM ORDERS(NOLOCK)
   WHERE Loadkey = @c_Loadkey

   SELECT @c_Userdefine04 = Userdefine04   --Loadtype
   FROM LOADPLAN (NOLOCK) 
   WHERE Loadkey = @c_Loadkey

   --SELECT @c_Option5 = ISNULL(Option5,'')
   --FROM Storerconfig (NOLOCK)
   --WHERE Storerkey = @c_Storerkey 
   --AND Configkey = 'SPLITLOADPLAN_SP'

   SELECT @c_MaxOrderPerLoad = ISNULL(CL.Short,'0')
   FROM CODELKUP CL (NOLOCK) 
   WHERE CL.Listname = 'HMMAXORDER' AND CL.Storerkey = @c_Storerkey
   AND CL.Code = @c_Userdefine04

   --SELECT @c_MaxOrderPerLoad = dbo.fnc_GetParamValueFromString('@c_MaxOrderPerLoad', @c_Option5, @c_MaxOrderPerLoad)  

   SELECT @c_MaxOrderPerLoad = ISNULL(@c_MaxOrderPerLoad,'0')

   SELECT @n_MaxOrderPerLoad = CASE WHEN ISNUMERIC(@c_MaxOrderPerLoad) = 1 THEN CAST(@c_MaxOrderPerLoad AS INT) ELSE 0 END

   --IF ISNUMERIC(@c_MaxOrderPerLoad) = 0
   --BEGIN
   --   SELECT @n_continue = 3
   --   SELECT @n_err = 61505
   --   SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Storerconfig.Option5 @c_MaxOrderPerLoad is not a number! (ispLPSPL02)"
   --   GOTO RETURN_SP
   --END
   --ELSE
   --BEGIN
   --   SELECT @n_MaxOrderPerLoad = CAST(@c_MaxOrderPerLoad AS INT)
   --END
   -------------------------- Construct Load Plan Dynamic Grouping ------------------------------
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        SET @c_Listname = 'LOADSPLIT'
        
        IF (SELECT COUNT(1) FROM CODELKUP (NOLOCK) WHERE Listname = @c_ListName AND Storerkey = @c_Storerkey) = 0
        BEGIN
           SELECT @n_continue = 3
           SELECT @n_err = 61510
           SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Load Plan Split Condition Is Not Setup Yet. (Listname: LOADSPLIT) (ispLPSPL02)"
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
   
           WHILE CharIndex('(', @c_TableColumnName) > 1
           BEGIN
              SET @c_TableColumnName = SUBSTRING(@c_TableColumnName, CharIndex('(', @c_TableColumnName) + 1, LEN(@c_TableColumnName) - CharIndex('(', @c_TableColumnName) - 1)
           END
           --SELECT @c_TableColumnName, LEN(@c_TableColumnName), CharIndex(')', @c_TableColumnName)
           WHILE CharIndex(')', @c_TableColumnName) > 1
           BEGIN
              SET @c_TableColumnName = SUBSTRING(@c_TableColumnName, 1, CharIndex(')', @c_TableColumnName) - 1)
           END
           
           SET @n_cnt = @n_cnt + 1
           SET @c_TableName = LEFT(@c_TableColumnName, CharIndex('.', @c_TableColumnName) - 1)
           SET @c_ColumnName = SUBSTRING(@c_TableColumnName,
                               CharIndex('.', @c_TableColumnName) + 1, LEN(@c_TableColumnName) - CharIndex('.', @c_TableColumnName))
           
           IF ISNULL(RTRIM(@c_TableName), '') NOT IN ('LOC', 'ORDERS')
           BEGIN
              SELECT @n_continue = 3
              SELECT @n_err = 61520
              SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Grouping Only Allow Refer To LOC Table's Fields. Invalid Table: "+RTRIM(@c_TableColumnName)+" (ispLPSPL02)"
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
              SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Invalid Column Name: " + RTRIM(@c_TableColumnName)+ ". (ispLPSPL02)"
              GOTO RETURN_SP
           END
   
           IF @c_ColumnType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint','text')
           BEGIN
              SELECT @n_continue = 3
              SELECT @n_err = 61540
              SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Numeric/Text Column Type Is Not Allowed For Load Plan Splitting: " + RTRIM(@c_TableColumnName)+ ". (ispLPSPL02)"
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
     BEGIN TRAN
   
   -------------------------- SPLIT LOAD PLAN ------------------------------
   
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         SELECT @c_SQLDYN01 = 'DECLARE cur_LPSplit CURSOR FAST_FORWARD READ_ONLY FOR ' + CHAR(13) + 
         + ' SELECT ORDERS.Storerkey ' + @c_SQLField  + CHAR(13) + 
         + ' FROM ORDERS WITH (NOLOCK) '
         + ' JOIN LoadPlanDetail LD WITH (NOLOCK) ON (ORDERS.OrderKey = LD.OrderKey) '  + CHAR(13) + 
         + ' LEFT JOIN PICKDETAIL PD WITH (NOLOCK) ON (PD.Orderkey = ORDERS.Orderkey) '  + CHAR(13) + 
         + ' LEFT JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) '  + CHAR(13) + 
         + ' WHERE LD.LoadKey = ''' +  RTRIM(@c_LoadKey) +''''  + CHAR(13) + 
         + ' GROUP BY ORDERS.Storerkey ' + @c_SQLGroup  + CHAR(13) + 
         + ' ORDER BY ORDERS.Storerkey ' + @c_SQLSort
   
         EXEC (@c_SQLDYN01)--PRINT @c_SQLDYN01
   
         OPEN cur_LPSplit
         
         FETCH NEXT FROM cur_LPSplit INTO @c_Storerkey, @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05,
                                          @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10
                                          
         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
         BEGIN
            SET @c_CurrentMaxFloor = @c_Field01
   
            IF @c_CurrentMaxFloor <> @c_PrevMaxFloor --OR ISNULL(@c_CurrentMaxFloor,'') = ''
            BEGIN
               SET @c_ToLoadkey = '' --every group split to new loadkey
               SELECT @n_loadcount = @n_loadcount + 1
               SET @n_OrderCount = 1
            END
   
            SELECT @c_SQLDYN02 = 'DECLARE cur_loadplansp CURSOR FAST_FORWARD READ_ONLY FOR ' + CHAR(13) + 
            + ' SELECT ORDERS.OrderKey, LD.LoadLineNumber '
            + ' FROM ORDERS WITH (NOLOCK) '
            + ' JOIN LOADPLANDETAIL LD WITH (NOLOCK) ON (ORDERS.OrderKey = LD.OrderKey) '
            + ' LEFT JOIN PICKDETAIL PD WITH (NOLOCK) ON (PD.Orderkey = ORDERS.Orderkey) '
            + ' LEFT JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) '
            + ' WHERE ORDERS.StorerKey = @c_StorerKey ' +
            + ' AND LD.Loadkey = @c_LoadKey '
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
                   SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Move Load Plan Order Failed. (ispLPSPL02)"
               END              
               
               --WL01 START
               IF NOT EXISTS (SELECT 1 FROM #TMP_FLOOR WHERE Loadkey = @c_ToLoadkey AND [Floor] = @c_CurrentMaxFloor)
               BEGIN
                  INSERT INTO #TMP_FLOOR
                  SELECT @c_ToLoadkey, @c_CurrentMaxFloor
               END
               --WL01 END                                	
            	
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
                     ,LOADPLAN.UserDefine01             = CASE WHEN ISNULL(@c_Field01,'') <> '' THEN @c_Field01 ELSE OL.UserDefine01 END            
                     ,LOADPLAN.UserDefine02             = CASE WHEN ISNULL(@c_Field02,'') <> '' THEN @c_Field02 ELSE OL.UserDefine02 END            
                     ,LOADPLAN.UserDefine03             = CASE WHEN ISNULL(@c_Field03,'') <> '' THEN @c_Field03 ELSE OL.UserDefine03 END            
                     ,LOADPLAN.UserDefine04             = CASE WHEN ISNULL(@c_Field04,'') <> '' THEN @c_Field04 ELSE OL.UserDefine04 END            
                     ,LOADPLAN.UserDefine05             = CASE WHEN ISNULL(@c_Field05,'') <> '' THEN @c_Field05 ELSE OL.UserDefine05 END            
                     ,LOADPLAN.UserDefine06             = CASE WHEN ISNULL(@c_Field06,'') <> '' THEN @c_Field06 ELSE OL.UserDefine06 END            
                     ,LOADPLAN.UserDefine07             = CASE WHEN ISNULL(@c_Field07,'') <> '' THEN @c_Field07 ELSE OL.UserDefine07 END            
                     ,LOADPLAN.UserDefine08             = CASE WHEN ISNULL(@c_Field08,'') <> '' THEN @c_Field08 ELSE OL.UserDefine08 END            
                     ,LOADPLAN.UserDefine09             = CASE WHEN ISNULL(@c_Field09,'') <> '' THEN @c_Field09 ELSE OL.UserDefine09 END            
                     ,LOADPLAN.UserDefine10             = CASE WHEN ISNULL(@c_Field10,'') <> '' THEN @c_Field10 ELSE OL.UserDefine10 END   
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
                     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update LOADPLAN Table Failed. (ispLPSPL02)"
                  END
   
                  UPDATE LOADPLANDETAIL WITH (ROWLOCK)       	       
                  SET LOADPLANDETAIL.ExternLoadKey = @c_Loadkey
                  WHERE LOADPLANDETAIL.Loadkey = @c_ToLoadKey
                 
                  SET @n_err = @@ERROR
                  IF @n_err <> 0  
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 61561
                     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update LOADPLANDETAIL Table Failed. (ispLPSPL02)"
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
   	          ,LOADPLAN.UserDefine01             = CASE WHEN ISNULL(@c_Field01,'') <> '' THEN @c_Field01 ELSE OL.UserDefine01 END            
   	          ,LOADPLAN.UserDefine02             = CASE WHEN ISNULL(@c_Field02,'') <> '' THEN @c_Field02 ELSE OL.UserDefine02 END            
   	          ,LOADPLAN.UserDefine03             = CASE WHEN ISNULL(@c_Field03,'') <> '' THEN @c_Field03 ELSE OL.UserDefine03 END            
   	          ,LOADPLAN.UserDefine04             = CASE WHEN ISNULL(@c_Field04,'') <> '' THEN @c_Field04 ELSE OL.UserDefine04 END            
   	          ,LOADPLAN.UserDefine05             = CASE WHEN ISNULL(@c_Field05,'') <> '' THEN @c_Field05 ELSE OL.UserDefine05 END            
   	          ,LOADPLAN.UserDefine06             = CASE WHEN ISNULL(@c_Field06,'') <> '' THEN @c_Field06 ELSE OL.UserDefine06 END            
   	          ,LOADPLAN.UserDefine07             = CASE WHEN ISNULL(@c_Field07,'') <> '' THEN @c_Field07 ELSE OL.UserDefine07 END            
   	          ,LOADPLAN.UserDefine08             = CASE WHEN ISNULL(@c_Field08,'') <> '' THEN @c_Field08 ELSE OL.UserDefine08 END            
   	          ,LOADPLAN.UserDefine09             = CASE WHEN ISNULL(@c_Field09,'') <> '' THEN @c_Field09 ELSE OL.UserDefine09 END            
   	          ,LOADPLAN.UserDefine10             = CASE WHEN ISNULL(@c_Field10,'') <> '' THEN @c_Field10 ELSE OL.UserDefine10 END   
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
                SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update LOADPLAN Table Failed. (ispLPSPL02)"
            END 
            
            UPDATE LOADPLANDETAIL WITH (ROWLOCK)       	       
            SET LOADPLANDETAIL.ExternLoadKey = @c_Loadkey
            WHERE LOADPLANDETAIL.Loadkey = @c_ToLoadKey
                 
            SET @n_err = @@ERROR
            IF @n_err <> 0  
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 61561
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update LOADPLANDETAIL Table Failed. (ispLPSPL02)"
            END                   
                                      	          
            SET @c_PrevMaxFloor = @c_Field01
   
            FETCH NEXT FROM cur_LPSplit INTO @c_Storerkey, @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05,
                            @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10
         END
         CLOSE cur_LPSplit
         DEALLOCATE cur_LPSplit
      END
   
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         IF @n_loadcount > 0
            SELECT @c_errmsg = RTRIM(CAST(@n_loadcount AS CHAR)) + ' Load Plan Generated'
         ELSE
            SELECT @c_errmsg = 'No Load Plan Generated'
      END
   END

   --WL01 START
   DECLARE @c_Batchno NVARCHAR(10) = '', @c_GetLoadkey NVARCHAR(10), @c_GetFloor NVARCHAR(10),
           @c_NewBatchno NVARCHAR(10),
           @n_TotalOrderCnt INT, @n_TotalOrderQty INT

   --Delete Parent Load from BuildLoadLog and BuildLoadDetailLog table AND add Child load into these 2 tables
   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      SELECT @c_Batchno = BatchNo
      FROM BuildLoadDetailLog (NOLOCK)
      WHERE Loadkey = @c_LoadKey AND Storerkey = @c_Storerkey

      --Store Parent BuildLoadLog and BuildLoadDetailLog Load Info into temp table
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

      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT Loadkey, [Floor]
      FROM #TMP_FLOOR

      OPEN CUR_LOOP

      FETCH NEXT FROM CUR_LOOP INTO @c_GetLoadkey, @c_GetFloor

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         INSERT INTO BuildLoadLog (Facility, Storerkey, BuildParmGroup, BuildParmCode, BuildParmString, Duration, TotalLoadCnt,
                                   UDF01, UDF02, UDF03, UDF04, UDF05, Status,
                                   Addwho, Adddate, EditWho, EditDate)
         SELECT Facility, Storerkey, BuildParmGroup,
                SUBSTRING(RTRIM(BuildParmCode) + '_' + LTRIM(RTRIM(@c_GetFloor)) + 'F',1,10),
                BuildParmString, Duration, TotalLoadCnt,
                UDF01, UDF02, UDF03, UDF04, 'ispLPSPL02', [Status],
                Addwho, Adddate, EditWho, EditDate
         FROM #TMP_BuildLoadLog

         SELECT @c_NewBatchno = SCOPE_IDENTITY()

         SET @n_err = @@ERROR
         IF @n_err <> 0  
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 61562
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": INSERT BuildLoadLog Table Failed. (ispLPSPL02)"
         END   

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
                UDF01, UDF02, UDF03, UDF04, 'ispLPSPL02',
                Addwho, Adddate, EditWho, EditDate
         FROM #TMP_BuildLoadDetailLog (NOLOCK) 

         SET @n_err = @@ERROR
         IF @n_err <> 0  
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 61563
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": INSERT BuildLoadDetailLog Table Failed. (ispLPSPL02)"
         END  

         FETCH NEXT FROM CUR_LOOP INTO @c_GetLoadkey, @c_GetFloor
      END

      --Delete Parent Load from BuildLoadLog and BuildLoadDetailLog table
      DELETE FROM BuildLoadDetailLog
      WHERE BatchNo = @c_Batchno AND Storerkey = @c_Storerkey

      SET @n_err = @@ERROR
      IF @n_err <> 0  
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 61564
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete BuildLoadDetailLog Table Failed. (ispLPSPL02)"
      END    

      DELETE FROM BuildLoadLog
      WHERE BatchNo = @c_Batchno AND Storerkey = @c_Storerkey

      SET @n_err = @@ERROR
      IF @n_err <> 0  
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 61565
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete BuildLoadLog Table Failed. (ispLPSPL02)"
      END   
   END

RETURN_SP:
   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END

   IF OBJECT_ID('tempdb..#TMP_BuildLoadDetailLog') IS NOT NULL
      DROP TABLE #TMP_BuildLoadDetailLog

   IF OBJECT_ID('tempdb..#TMP_BuildLoadLog') IS NOT NULL
      DROP TABLE #TMP_BuildLoadLog

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
    EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispLPSPL02'
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

GO