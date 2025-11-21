SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  ispLPSPL01                                         */
/* Creation Date:  23-Nov-2017                                          */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  WMS-3160 Split Load plan                                   */
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
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver  Purposes                                   */
/************************************************************************/
CREATE PROC [dbo].[ispLPSPL01]
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

 DECLARE @c_ListName         NVARCHAR(10)
         ,@c_Code            NVARCHAR(30) -- e.g. ORDERS01
         ,@c_Description     NVARCHAR(250)
         ,@c_TableColumnName NVARCHAR(250)  -- e.g. ORDERS.Orderkey
         ,@c_TableName  NVARCHAR(30)
         ,@c_ColumnName NVARCHAR(30)
         ,@c_ColumnType NVARCHAR(10)
         ,@c_SQLField   NVARCHAR(2000)
         ,@c_SQLWhere   NVARCHAR(2000)
         ,@c_SQLGroup   NVARCHAR(2000)
         ,@c_SQLDYN01   NVARCHAR(2000)
         ,@c_SQLDYN02   NVARCHAR(2000)
         ,@c_Field01    NVARCHAR(60)
         ,@c_Field02    NVARCHAR(60)
         ,@c_Field03    NVARCHAR(60)
         ,@c_Field04    NVARCHAR(60)
         ,@c_Field05    NVARCHAR(60)
         ,@c_Field06    NVARCHAR(60)
         ,@c_Field07    NVARCHAR(60)
         ,@c_Field08    NVARCHAR(60)
         ,@c_Field09    NVARCHAR(60)
         ,@c_Field10    NVARCHAR(60)
         ,@n_cnt        INT

 SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue = 1, @n_loadcount = 0

-------------------------- Construct Load Plan Dynamic Grouping ------------------------------
 IF @n_continue = 1 OR @n_continue = 2
 BEGIN
     SET @c_Listname = 'LOADSPLIT'
     
     SELECT TOP 1 @c_Storerkey = Storerkey,
                  @c_Facility = Facility
     FROM ORDERS(NOLOCK)
     WHERE Loadkey = @c_Loadkey
     
     IF (SELECT COUNT(1) FROM CODELKUP (NOLOCK) WHERE Listname = @c_ListName AND Storerkey = @c_Storerkey) = 0
     BEGIN
        SELECT @n_continue = 3
        SELECT @n_err = 61510
        SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Load Plan Split Condition Is Not Setup Yet. (Listname: LOADSPLIT) (ispLPSPL01)"
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

     SELECT @c_SQLField = '', @c_SQLWhere = '', @c_SQLGroup = '', @n_cnt = 0
     WHILE @@FETCH_STATUS <> -1
     BEGIN
        SET @n_cnt = @n_cnt + 1
        SET @c_TableName = LEFT(@c_TableColumnName, CharIndex('.', @c_TableColumnName) - 1)
        SET @c_ColumnName = SUBSTRING(@c_TableColumnName,
                            CharIndex('.', @c_TableColumnName) + 1, LEN(@c_TableColumnName) - CharIndex('.', @c_TableColumnName))

        IF ISNULL(RTRIM(@c_TableName), '') <> 'ORDERS'
        BEGIN
           SELECT @n_continue = 3
           SELECT @n_err = 61520
           SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Grouping Only Allow Refer To Orders Table's Fields. Invalid Table: "+RTRIM(@c_TableColumnName)+" (ispLPSPL01)"
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
           SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Invalid Column Name: " + RTRIM(@c_TableColumnName)+ ". (ispLPSPL01)"
           GOTO RETURN_SP
        END

        IF @c_ColumnType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint','text')
        BEGIN
           SELECT @n_continue = 3
           SELECT @n_err = 61540
           SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Numeric/Text Column Type Is Not Allowed For Load Plan Splitting: " + RTRIM(@c_TableColumnName)+ ". (ispLPSPL01)"
           GOTO RETURN_SP
        END

        IF @c_ColumnType IN ('char', 'nvarchar', 'varchar')
        BEGIN
           SELECT @c_SQLField = @c_SQLField + ',' + RTRIM(@c_TableColumnName)
           SELECT @c_SQLWhere = @c_SQLWhere + ' AND ' + RTRIM(@c_TableColumnName) + '=' +
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

        IF @c_ColumnType IN ('datetime')
        BEGIN
           SELECT @c_SQLField = @c_SQLField + ', CONVERT(VARCHAR(10),' + RTRIM(@c_TableColumnName) + ',112)'
           SELECT @c_SQLWhere = @c_SQLWhere + ' AND CONVERT(VARCHAR(10),' + RTRIM(@c_TableColumnName) + ',112)=' +
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

        FETCH NEXT FROM CUR_CODELKUP INTO @c_Code, @c_Description, @c_TableColumnName
     END
     CLOSE CUR_CODELKUP
     DEALLOCATE CUR_CODELKUP
     
     SELECT @n_NoOfGroupField = @n_cnt 

     SELECT @c_SQLGroup = @c_SQLField
     WHILE @n_cnt < 10
     BEGIN
        SET @n_cnt = @n_cnt + 1
         SELECT @c_SQLField = @c_SQLField + ','''''

        SELECT @c_SQLWhere = @c_SQLWhere + ' AND ''''=' +
               CASE WHEN @n_cnt = 1 THEN 'ISNULL(@c_Field01,'''')'
                    WHEN @n_cnt = 2 THEN 'ISNULL(@c_Field02,'''')'
                    WHEN @n_cnt = 3 THEN 'ISNULL(@c_Field03,'''')'
                    WHEN @n_cnt = 4 THEN 'ISNULL(@c_Field04,'''')'
                    WHEN @n_cnt = 5 THEN 'ISNULL(@c_Field05,'''')'
                    WHEN @n_cnt = 6 THEN 'ISNULL(@c_Field06,'''')'
                    WHEN @n_cnt = 7 THEN 'ISNULL(@c_Field07,'''')'
                    WHEN @n_cnt = 8 THEN 'ISNULL(@c_Field08,'''')'
                    WHEN @n_cnt = 9 THEN 'ISNULL(@c_Field09,'''')'
                    WHEN @n_cnt = 10 THEN 'ISNULL(@c_Field10,'''')' 
               END
     END
  END

 BEGIN TRAN

-------------------------- SPLIT LOAD PLAN ------------------------------

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_SQLDYN01 = 'DECLARE cur_LPSplit CURSOR FAST_FORWARD READ_ONLY FOR '
      + ' SELECT ORDERS.Storerkey ' + @c_SQLField
      + ' FROM ORDERS WITH (NOLOCK) '
      + ' JOIN LoadPlanDetail LD WITH (NOLOCK) ON (ORDERS.OrderKey = LD.OrderKey) '
      +'  WHERE LD.LoadKey = ''' +  RTRIM(@c_LoadKey) +''''
      + ' GROUP BY ORDERS.Storerkey ' + @c_SQLGroup
      + ' ORDER BY ORDERS.Storerkey ' + @c_SQLGroup

      EXEC (@c_SQLDYN01)

      OPEN cur_LPSplit
      
      FETCH NEXT FROM cur_LPSplit INTO @c_Storerkey, @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05,
                                       @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10
                                       
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN
      	 SET @c_ToLoadkey = '' --every group split to new loadkey
         SELECT @n_loadcount = @n_loadcount + 1
      	
         SELECT @c_SQLDYN02 = 'DECLARE cur_loadplansp CURSOR FAST_FORWARD READ_ONLY FOR '
         + ' SELECT ORDERS.OrderKey, LD.LoadLineNumber '
         + ' FROM ORDERS WITH (NOLOCK) '
         + ' JOIN LOADPLANDETAIL LD WITH (NOLOCK) ON (ORDERS.OrderKey = LD.OrderKey) '
         + ' WHERE ORDERS.StorerKey = @c_StorerKey ' +
         + ' AND LD.Loadkey = @c_LoadKey '
         + @c_SQLWhere
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
         BEGIN                      	
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
                SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Move Load Plan Order Failed. (ispLPSPL01)"
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
             SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update LOADPLAN Table Failed. (ispLPSPL01)"
         END                                              	          
         
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

RETURN_SP:

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
    EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispLPSPL01'
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