SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  

/* Store Procedure:  ispWAVLP07                                         */  

/* Creation Date:  27-OCT-2021                                          */  

/* Copyright: LF                                                        */  

/* Written by:                                                          */  

/*                                                                      */  

/* Purpose:  WMS-18212 - Create load plan by wave. Configurable by      */  

/*           max order per load and order sorting within a group        */

/*                                                                      */  

/* Input Parameters:  @c_WaveKey  - (WaveKey)                           */  

/*                                                                      */  

/* Output Parameters:  None                                             */  

/*                                                                      */  

/* Return Status:  None                                                 */  

/*                                                                      */  

/* Usage:                                                               */  

/*                                                                      */  

/* Local Variables:                                                     */  

/*                                                                      */  

/* Called By:  RMC Generate Load Plan By Consignee                      */

/*             wrapper: isp_WaveGenLoadPlan_Wrapper                     */  

/*             storerconfig: WAVEGENLOADPLAN                            */ 

/*                                                                      */  

/* PVCS Version: 1.0                                                    */  

/*                                                                      */  

/* Version: 7.0                                                         */  

/*                                                                      */  

/* Data Modifications:                                                  */  

/*                                                                      */  

/* Updates:                                                             */  

/* Date        Author   Ver  Purposes                                   */  

/* 27-Oct-2021 NJOW01   1.0  DEVOPS combine script                      */

/* 18-Apr-2023 NJOW02	  1.1  Fix no break loadplan problem              */

/************************************************************************/  

CREATE PROC [dbo].[ispWAVLP07]   

   @c_WaveKey NVARCHAR(10),  

   @b_Success int OUTPUT,   

   @n_err     int OUTPUT,   

   @c_errmsg  NVARCHAR(250) OUTPUT   

AS  

BEGIN    

   SET NOCOUNT ON  

   SET QUOTED_IDENTIFIER OFF   

   SET ANSI_NULLS OFF     

   SET CONCAT_NULL_YIELDS_NULL OFF      

  

   DECLARE @c_ConsigneeKey      NVARCHAR( 15)  

           ,@c_Priority          NVARCHAR( 10)  

           ,@c_C_Company         NVARCHAR( 45)  

           ,@c_OrderKey          NVARCHAR( 10)  

           ,@c_Facility          NVARCHAR( 5)  

           ,@c_ExternOrderKey    NVARCHAR( 50)    

           ,@c_StorerKey         NVARCHAR( 15)  

           ,@c_Route             NVARCHAR( 10)  

           ,@c_debug             NVARCHAR( 1)  

           ,@c_loadkey           NVARCHAR( 10)  

           ,@n_continue          INT  

           ,@n_StartTranCnt      INT  

           ,@d_OrderDate         DATETIME  

           ,@d_Delivery_Date     DATETIME   

           ,@c_OrderType         NVARCHAR( 10)  

           ,@c_Door              NVARCHAR( 10)  

           ,@c_DeliveryPlace     NVARCHAR( 30)  

           ,@c_OrderStatus       NVARCHAR( 10)  

           ,@n_loadcount         INT  

           ,@n_TotWeight         FLOAT  

           ,@n_TotCube           FLOAT  

           ,@n_TotOrdLine        INT  

           ,@c_NewLoad             NVARCHAR(1) --NJOW02

                                               

   DECLARE @c_ListName NVARCHAR(10)  

           ,@c_Code NVARCHAR(30) -- e.g. ORDERS01  

           ,@c_Description NVARCHAR(250)  

           ,@c_TableColumnName NVARCHAR(250)  -- e.g. ORDERS.Orderkey  

           ,@c_TableName NVARCHAR(30)  

           ,@c_ColumnName NVARCHAR(30)  

           ,@c_ColumnType NVARCHAR(10)  

           ,@c_SQLField NVARCHAR(2000)  

           ,@c_SQLWhere NVARCHAR(2000)  

           ,@c_SQLGroup NVARCHAR(2000)  

           ,@c_SQLDYN01 NVARCHAR(2000)  

           ,@c_SQLDYN02 NVARCHAR(2000)  

           ,@c_SQLDYN03 NVARCHAR(2000)

           ,@c_Field01 NVARCHAR(60)  

           ,@c_Field02 NVARCHAR(60)  

           ,@c_Field03 NVARCHAR(60)  

           ,@c_Field04 NVARCHAR(60)  

           ,@c_Field05 NVARCHAR(60)  

           ,@c_Field06 NVARCHAR(60)  

           ,@c_Field07 NVARCHAR(60)  

           ,@c_Field08 NVARCHAR(60)  

           ,@c_Field09 NVARCHAR(60)  

           ,@c_Field10 NVARCHAR(60)  

           ,@n_cnt int  

           ,@c_FoundLoadkey NVARCHAR(10)

           ,@c_DocType             NVARCHAR(1) 

           ,@c_SuperOrderFlag      NVARCHAR(1) 

           ,@c_DefaultStrategy     NVARCHAR(1) 

           ,@n_NoOfGroupField      INT 

           ,@c_Load_Userdef1       NVARCHAR(4000) 

           ,@c_Authority           NVARCHAR(10)

           ,@n_OrderCnt            INT

           ,@n_MaxOrderPerLoad     INT

           ,@c_OrderSort           NVARCHAR(2000)

       

   DECLARE @n_TablePos INT, 

           @n_TableNameLen INT,

           @n_EndPos1 INT, 

           @n_EndPos2 INT, 

           @n_EndPos3 INT, 

           @n_RtnPos1 INT, 

           @n_RtnPos2 INT

            

   SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue = 1, @n_loadcount = 0, @n_OrderCnt = 0, @n_MaxOrderPerLoad  = 99999

  

   -------------------------- Wave Validation ------------------------------    

   IF NOT EXISTS(SELECT 1 

                 FROM WaveDetail WITH (NOLOCK)   

                 WHERE WaveKey = @c_WaveKey)  

   BEGIN  

      SELECT @n_continue = 3  

      SELECT @n_err = 63500  

      SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": No Orders being populated into WaveDetail. (ispWAVLP07)"  

      GOTO RETURN_SP  

   END  

  

   -------------------------- Construct Load Plan Dynamic Grouping ------------------------------    

   IF @n_continue = 1 OR @n_continue = 2  

   BEGIN                    

      SELECT @c_listname = CODELIST.Listname

             --@n_MaxOrderPerLoad = CASE WHEN ISNUMERIC(CODELIST.UDF01) = 1 THEN CAST(CODELIST.UDF01 AS INT) ELSE 99999 END

      FROM WAVE (NOLOCK)   

      JOIN CODELIST (NOLOCK) ON WAVE.LoadPlanGroup = CODELIST.Listname AND CODELIST.ListGroup = 'WAVELPGROUP'  

      WHERE WAVE.Wavekey = @c_WaveKey  

      

      --IF ISNULL(@n_MaxOrderPerLoad,0) = 0 

      --   SET @n_MaxOrderPerLoad  = 99999

        

      IF ISNULL(@c_ListName,'') = ''  

      BEGIN  

          SELECT @n_continue = 3  

          SELECT @n_err = 63510  

          SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Empty/Invalid Load Plan Group Is Not Allowed. (LIST GROUP: WAVELPGROUP) (ispWAVLP07)"  

          GOTO RETURN_SP                      

      END

      

      SELECT TOP 1 @n_MaxOrderPerLoad = CASE WHEN ISNUMERIC(CL.Long) = 1 THEN CAST(CL.Long AS INT) ELSE 99999 END

      FROM CODELKUP CL (NOLOCK)

      WHERE CL.Listname = @c_ListName

      AND CL.Code = 'MAXORDER'

      

      IF ISNULL(@n_MaxOrderPerLoad,0) = 0 

         SET @n_MaxOrderPerLoad  = 99999  



      SELECT TOP 1 @c_OrderSort = CL.Long

      FROM CODELKUP CL (NOLOCK)

      WHERE CL.Listname = @c_ListName

      AND CL.Code = 'SORTORDER'         

      

      IF ISNULL(@c_OrderSort,'') <> ''

      BEGIN

      	IF LEFT(LTRIM(@c_OrderSort),8) <> 'ORDER BY'

      	BEGIN

      	   SET @c_OrderSort = ' ORDER BY ' + LTRIM(@c_OrderSort)

      	END

      END

      ELSE

      BEGIN

        SET @c_OrderSort = ' ORDER BY ORDERS.OrderKey '

      END

                          

      DECLARE CUR_CODELKUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  

         SELECT TOP 10 Code, Description, Long   

         FROM   CODELKUP WITH (NOLOCK)  

         WHERE  ListName = @c_ListName  

         AND Code NOT IN('MAXORDER','SORTORDER')

         ORDER BY Code  

         

      OPEN CUR_CODELKUP  

        

      FETCH NEXT FROM CUR_CODELKUP INTO @c_Code, @c_Description, @c_TableColumnName  

        

      SELECT @c_SQLField = '', @c_SQLWhere = '', @c_SQLGroup = '', @n_cnt = 0  

      WHILE @@FETCH_STATUS <> -1  

      BEGIN  

         SET @n_cnt = @n_cnt + 1   

   

         IF CHARINDEX('(', @c_TableColumnName, 1) > 0 -- support field name with function

         BEGIN

            SELECT @c_TableName = 'ORDERS'

            SELECT @n_TableNameLen = LEN(@c_TableName)

            SELECT @n_TablePos = CHARINDEX(@c_TableName, @c_TableColumnName, 1)

            

            IF @n_TablePos <= 0

            BEGIN

               SELECT @n_continue = 3

               SELECT @n_err = 63520

               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Grouping Only Allow Refer To Orders Table's Fields. Invalid Table: "+RTRIM(@c_TableColumnName)+" (ispWAVLP07)"

               GOTO RETURN_SP

            END

            

            SELECT @n_EndPos1 = CHARINDEX(',',@c_TableColumnName, @n_TablePos + @n_TableNameLen)

            SELECT @n_EndPos2 = CHARINDEX(')',@c_TableColumnName, @n_TablePos + @n_TableNameLen)

            SELECT @n_EndPos3 = CHARINDEX(' ',@c_TableColumnName, @n_TablePos + @n_TableNameLen)

   

            IF @n_EndPos1 = 0

               SET @n_RtnPos1 = @n_EndPos2

            ELSE IF @n_EndPos2 = 0   

               SET @n_RtnPos1 = @n_EndPos1

            ELSE IF @n_EndPos1 > @n_EndPos2

              SET @n_RtnPos1 = @n_EndPos2

            ELSE

              SET @n_RtnPos1= @n_EndPos1

            

            IF @n_RtnPos1 = 0

               SET @n_RtnPos2 = @n_EndPos3

            ELSE IF @n_EndPos3 = 0   

               SET @n_RtnPos2 = @n_RtnPos1

            ELSE IF @n_RtnPos1 > @n_EndPos3

              SET @n_RtnPos2 = @n_EndPos3

            ELSE

              SET @n_RtnPos2= @n_RtnPos1

                         

            IF @n_RtnPos2 > 0  -- +1 is comma  @n_RtnPos2 is position of close symbol ,)

               SELECT @c_ColumnName = RTRIM(SUBSTRING(@c_TableColumnName, @n_TablePos + @n_TableNameLen + 1, @n_RtnPos2 - (@n_TablePos + @n_TableNameLen + 1) ))

            ELSE

               SELECT @c_ColumnName = RTRIM(SUBSTRING(@c_TableColumnName, @n_TablePos + @n_TableNameLen + 1, LEN(@c_TableColumnName)))

         END

         ELSE

         BEGIN           

            SET @c_TableName = LEFT(@c_TableColumnName, CharIndex('.', @c_TableColumnName) - 1)  

            SET @c_ColumnName = SUBSTRING(@c_TableColumnName,   

                                CharIndex('.', @c_TableColumnName) + 1, LEN(@c_TableColumnName) - CharIndex('.', @c_TableColumnName))  

            

            IF ISNULL(RTRIM(@c_TableName), '') <> 'ORDERS'   

            BEGIN  

               SELECT @n_continue = 3  

               SELECT @n_err = 63530  

               SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Grouping Only Allow Refer To Orders Table's Fields. Invalid Table: "+RTRIM(@c_TableColumnName)+" (ispWAVLP07)"  

               GOTO RETURN_SP                      

            END   

         END

        

         SET @c_ColumnType = ''  

         SELECT @c_ColumnType = DATA_TYPE   

         FROM   INFORMATION_SCHEMA.COLUMNS   

         WHERE  TABLE_NAME = @c_TableName  

         AND    COLUMN_NAME = @c_ColumnName  

        

         IF ISNULL(RTRIM(@c_ColumnType), '') = ''   

         BEGIN  

            SELECT @n_continue = 3  

            SELECT @n_err = 63540  

            SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Invalid Column Name: " + RTRIM(@c_TableColumnName)+ ". (ispWAVLP07)"  

            GOTO RETURN_SP                      

         END   

           

         IF @c_ColumnType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint','text')  

         BEGIN  

            SELECT @n_continue = 3  

            SELECT @n_err = 63550  

            SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Numeric/Text Column Type Is Not Allowed For Load Plan Grouping: " + RTRIM(@c_TableColumnName)+ ". (ispWAVLP07)"  

            GOTO RETURN_SP                      

         END   

        

         IF @c_ColumnType IN ('char', 'nvarchar', 'varchar', 'nchar')  

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

            SELECT @c_SQLField = @c_SQLField + ', CONVERT(NVARCHAR(10),' + RTRIM(@c_TableColumnName) + ',112)'  

            SELECT @c_SQLWhere = @c_SQLWhere + ' AND CONVERT(NVARCHAR(10),' + RTRIM(@c_TableColumnName) + ',112)=' +   

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

                     WHEN @n_cnt = 10 THEN 'ISNULL(@c_Field10,'''')' END          

      END  

   END  



   WHILE @@ROWCOUNT > 0

      COMMIT TRAN

                    

   -------------------------- CREATE LOAD PLAN ------------------------------     

   IF @n_continue = 1 OR @n_continue = 2  

   BEGIN        

      SELECT @c_SQLDYN01 = 'DECLARE cur_LPGroup CURSOR FAST_FORWARD READ_ONLY FOR '  

      + ' SELECT ORDERS.Storerkey ' + @c_SQLField   

      + ' FROM ORDERS WITH (NOLOCK) '  

      + ' JOIN WaveDetail WD WITH (NOLOCK) ON (ORDERS.OrderKey = WD.OrderKey) '  

      +'  WHERE WD.WaveKey = ''' +  RTRIM(@c_WaveKey) +''''  

      + ' AND ISNULL(ORDERS.Loadkey,'''') = '''' '  

      + ' AND ORDERS.Status NOT IN (''9'',''CANC'') '  

      + ' GROUP BY ORDERS.Storerkey ' + @c_SQLGroup  

      + ' ORDER BY ORDERS.Storerkey ' + @c_SQLGroup  

        

      EXEC (@c_SQLDYN01)  

  

      OPEN cur_LPGroup  

      

      FETCH NEXT FROM cur_LPGroup INTO @c_Storerkey, @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05,   

                                       @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10  

                                       

      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)

      BEGIN      	 

      	 SET @c_NewLoad = 'Y' --NJOW02

      	

         BEGIN TRAN TRN_LOAD;

         

         SELECT @n_cnt = 1, @c_Load_Userdef1 = ''  

         

         WHILE @n_cnt <= @n_NoOfGroupField

         BEGIN          

           SELECT @c_Load_Userdef1 = @c_Load_Userdef1 + 

               CASE WHEN @n_cnt = 1 THEN LTRIM(RTRIM(ISNULL(@c_Field01,'')))

                    WHEN @n_cnt = 2 THEN '-' + LTRIM(RTRIM(ISNULL(@c_Field02,'')))

                    WHEN @n_cnt = 3 THEN '-' + LTRIM(RTRIM(ISNULL(@c_Field03,'')))

                    WHEN @n_cnt = 4 THEN '-' + LTRIM(RTRIM(ISNULL(@c_Field04,'')))

                    WHEN @n_cnt = 5 THEN '-' + LTRIM(RTRIM(ISNULL(@c_Field05,'')))

                    WHEN @n_cnt = 6 THEN '-' + LTRIM(RTRIM(ISNULL(@c_Field06,'')))

                    WHEN @n_cnt = 7 THEN '-' + LTRIM(RTRIM(ISNULL(@c_Field07,'')))

                    WHEN @n_cnt = 8 THEN '-' + LTRIM(RTRIM(ISNULL(@c_Field08,'')))

                    WHEN @n_cnt = 9 THEN '-' + LTRIM(RTRIM(ISNULL(@c_Field09,'')))

                    WHEN @n_cnt = 10 THEN '-' + LTRIM(RTRIM(ISNULL(@c_Field10,''))) END            

                        

            SET @n_cnt = @n_cnt + 1

         END	

           

         SET @c_FoundLoadkey = ''

         

         SELECT @c_SQLDYN03 = ' SELECT TOP 1 @c_FoundLoadkey = ORDERS.Loadkey '  

         + ' FROM ORDERS WITH (NOLOCK) '  

         + ' JOIN WaveDetail WD WITH (NOLOCK) ON (ORDERS.OrderKey = WD.OrderKey) '  

         + ' WHERE  ORDERS.StorerKey = @c_StorerKey '   

         + ' AND WD.WaveKey = @c_WaveKey '  

         + ' AND ORDERS.Status NOT IN (''9'',''CANC'') '  

         + ' AND ISNULL(ORDERS.Loadkey,'''') <> '''' '  

         + @c_SQLWhere  

         + ' ORDER BY ORDERS.Loadkey DESC '  

                 

         EXEC sp_executesql @c_SQLDYN03,   

              N'@c_Storerkey NVARCHAR(15), @c_Wavekey NVARCHAR(10), @c_Field01 NVARCHAR(60), @c_Field02 NVARCHAR(60),@c_Field03 NVARCHAR(60),@c_Field04 NVARCHAR(60),  

                @c_Field05 NVARCHAR(60), @c_Field06 NVARCHAR(60), @c_Field07 NVARCHAR(60), @c_Field08 NVARCHAR(60), @c_Field09 NVARCHAR(60), @c_Field10 NVARCHAR(60), @c_FoundLoadkey NVARCHAR(10) OUTPUT',   

              @c_Storerkey,  

              @c_Wavekey,                        

              @c_Field01,   

              @c_Field02,   

              @c_Field03,   

              @c_Field04,    

              @c_Field05,   

              @c_Field06,   

              @c_Field07,   

              @c_Field08,   

              @c_Field09,   

              @c_Field10,  

              @c_FoundLoadkey OUTPUT   

               

         IF ISNULL(@c_FoundLoadkey,'') <> '' AND NOT EXISTS (SELECT 1        

                                                             FROM ORDERS (NOLOCK)                 

                                                             WHERE Loadkey = @c_FoundLoadkey 

                                                             AND ISNULL(Loadkey,'') <> ''

                                                             AND userdefine09 <> @c_Wavekey)   

         BEGIN                                                                                                                                 

            SET @c_loadkey = @c_FoundLoadkey            

            SELECT @n_loadcount = @n_loadcount + 1  

            SET @c_NewLoad = 'N' --NJOW02            

            

            SELECT @n_OrderCnt = COUNT(1)

            FROM LOADPLANDETAIL (NOLOCK)

            WHERE Loadkey = @c_Loadkey

         END

                               

         -- Create loadplan detail       

         SELECT @c_SQLDYN02 = 'DECLARE cur_loadpland CURSOR FAST_FORWARD READ_ONLY FOR '  

         + ' SELECT ORDERS.OrderKey '  

         + ' FROM ORDERS WITH (NOLOCK) '  

         + ' JOIN WaveDetail WD WITH (NOLOCK) ON (ORDERS.OrderKey = WD.OrderKey) '  

         + ' WHERE  ORDERS.StorerKey = @c_StorerKey ' +  

         + ' AND WD.WaveKey = @c_WaveKey '  

         + ' AND ORDERS.Status NOT IN (''9'',''CANC'') '  

         + ' AND ISNULL(ORDERS.Loadkey,'''') = '''' '  

         + @c_SQLWhere  

         + @c_OrderSort

         --+ ' ORDER BY ORDERS.ExternOrderkey DESC, ORDERS.Adddate, ORDERS.OrderKey '  

  

         EXEC sp_executesql @c_SQLDYN02,   

              N'@c_Storerkey NVARCHAR(15), @c_Wavekey NVARCHAR(10), @c_Field01 NVARCHAR(60), @c_Field02 NVARCHAR(60),@c_Field03 NVARCHAR(60),@c_Field04 NVARCHAR(60),  

                @c_Field05 NVARCHAR(60), @c_Field06 NVARCHAR(60), @c_Field07 NVARCHAR(60), @c_Field08 NVARCHAR(60), @c_Field09 NVARCHAR(60), @c_Field10 NVARCHAR(60)',   

              @c_Storerkey,  

              @c_Wavekey,                        

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

  

         OPEN cur_loadpland  

  

         FETCH NEXT FROM cur_loadpland INTO @c_OrderKey  

         

         WHILE @@FETCH_STATUS = 0  AND @n_continue IN(1,2)

         BEGIN                              	  

         	  SET @n_OrderCnt = @n_OrderCnt + 1

         	  

         	  IF @n_OrderCnt > @n_MaxOrderPerLoad OR @n_loadcount = 0

         	     OR @c_NewLoad = 'Y' --NJOW02

         	  BEGIN

               SELECT @c_SuperOrderFlag = 'N', @c_DefaultStrategy = 'N', @c_Doctype = '', @c_facility = '', @n_OrderCnt = 1

       	  	   SET @c_NewLoad = 'N' --NJOW02               

         	  	 

         	  	 SELECT @n_loadcount = @n_loadcount + 1          	  	 

         	  	 

               SELECT @c_facility = ORDERS.Facility,

                      @c_Doctype = ORDERS.Doctype 

               FROM ORDERS (NOLOCK) 

               WHERE ORDERS.Orderkey = @c_Orderkey

               

               SELECT @c_authority = '', @b_success = 0

               EXECUTE nspGetRight

                  @c_facility,

                  @c_StorerKey,          -- Storer

                  NULL,   -- Sku

                  'AutoUpdSupOrdflag', -- ConfigKey

                  @b_success    output,

                  @c_authority  output,

                  @n_err        output,

                  @c_errmsg     output

               

               IF @b_success <> 1

               BEGIN

                  SELECT @n_continue = 3

                  SELECT @c_errmsg = 'ispWAVLP07:' + RTRIM(ISNULL(@c_errmsg,''))

               END

               ELSE IF @c_authority  = '1'

               BEGIN

                   SELECT @c_SuperOrderFlag = 'Y'

               END

      

               IF @c_DocType = 'E' 

               BEGIN

                  SELECT @c_authority = '', @b_success = 0

                  EXECUTE nspGetRight

                     @c_facility,

                     @c_StorerKey,          -- Storer

                     NULL,   -- Sku

                     'GenEcomLPSetSuperOrderFlag', -- ConfigKey

                     @b_success    output,

                     @c_authority  output,

                     @n_err        output,

                     @c_errmsg     output

                  

                  IF @b_success <> 1

                  BEGIN

                     SELECT @n_continue = 3

                     SELECT @c_errmsg = 'ispWAVLP07:' + RTRIM(ISNULL(@c_errmsg,''))

                  END

                  ELSE IF @c_authority  = '1'

                  BEGIN

                     SELECT @c_SuperOrderFlag = 'Y'

                  END

               

                  SELECT @c_authority = '', @b_success = 0

                  EXECUTE nspGetRight

                     @c_facility,

                     @c_StorerKey,          -- Storer

                     NULL,   -- Sku

                     'GenEcomLPSetDefaultStrategy', -- ConfigKey

                     @b_success    output,

                     @c_authority  output,

                     @n_err        output,

                     @c_errmsg     output

                  

                  IF @b_success <> 1

                  BEGIN

                     SELECT @n_continue = 3

                     SELECT @c_errmsg = 'ispWAVLP07:' + RTRIM(ISNULL(@c_errmsg,''))

                  END

                  ELSE IF @c_authority  = '1'

                  BEGIN

                      SELECT @c_DefaultStrategy = 'Y'

                  END

               END



               SELECT @b_success = 0  

               EXECUTE nspg_GetKey  

                  'LOADKEY',  

                  10,  

                  @c_loadkey     OUTPUT,  

                  @b_success     OUTPUT,  

                  @n_err         OUTPUT,  

                  @c_errmsg      OUTPUT  

                 

               IF @b_success <> 1  

               BEGIN  

                  SELECT @n_continue = 3  

               END           	  	 



               INSERT INTO LoadPlan (LoadKey, Facility, Userdefine09, SuperOrderFlag, DefaultStrategyKey, Load_Userdef1)  

               VALUES (@c_loadkey, @c_Facility, @c_WaveKey, @c_SuperOrderFlag, @c_DefaultStrategy, @c_Load_Userdef1)  

                 

               SELECT @n_err = @@ERROR  

                   

               IF @n_err <> 0   

               BEGIN  

                  SELECT @n_continue = 3  

                  SELECT @n_err = 63560  

                  SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Insert Into LOADPLAN Failed. (ispWAVLP07)"  

               END                                         

         	  END

         	      

            IF (SELECT COUNT(1) FROM LoadPlanDetail WITH (NOLOCK) WHERE OrderKey = @c_OrderKey) = 0  

            BEGIN  

               SELECT @d_OrderDate = O.OrderDate,   

                      @d_Delivery_Date = O.DeliveryDate,   

                      @c_OrderType = O.Type,  

                      @c_Door = O.Door,  

                      @c_Route = O.Route,  

                      @c_DeliveryPlace = O.DeliveryPlace,  

                      @c_OrderStatus = O.Status,  

                      @c_priority = O.Priority,  

                      @n_totweight = SUM(OD.OpenQty * SKU.StdGrossWgt),  

                      @n_totcube = SUM(OD.OpenQty * SKU.StdCube),  

                      @n_TotOrdLine = COUNT(DISTINCT OD.OrderLineNumber),  

                      @c_C_Company = O.C_Company,  

                      @c_ExternOrderkey = O.ExternOrderkey,  

                      @c_Consigneekey = O.Consigneekey  

               FROM Orders O WITH (NOLOCK)  

               JOIN Orderdetail OD WITH (NOLOCK) ON (O.Orderkey = OD.Orderkey)  

               JOIN SKU WITH (NOLOCK) ON (OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku)  

               WHERE O.OrderKey = @c_OrderKey    

               GROUP BY O.OrderDate,   

                        O.DeliveryDate,   

                        O.Type,  

                        O.Door,  

                        O.Route,  

                        O.DeliveryPlace,  

                        O.Status,  

                        O.Priority,  

                        O.C_Company,  

                        O.ExternOrderkey,  

                        O.Consigneekey  

  

               EXEC isp_InsertLoadplanDetail   

                    @cLoadKey          = @c_LoadKey,  

                    @cFacility         = @c_Facility,              

                    @cOrderKey         = @c_OrderKey,             

                    @cConsigneeKey     = @c_Consigneekey,  

                    @cPrioriry         = @c_Priority,    

                    @dOrderDate        = @d_OrderDate,  

                    @dDelivery_Date    = @d_Delivery_Date,      

                    @cOrderType        = @c_OrderType,     

                    @cDoor             = @c_Door,              

                    @cRoute            = @c_Route,                          

                    @cDeliveryPlace    = @c_DeliveryPlace,  

                    @nStdGrossWgt      = @n_totweight,        

                    @nStdCube          = @n_totcube,           

                    @cExternOrderKey   = @c_ExternOrderKey,     

                    @cCustomerName     = @c_C_Company,  

                    @nTotOrderLines    = @n_TotOrdLine,      

                    @nNoOfCartons      = 0,  

                    @cOrderStatus      = @c_OrderStatus,                  

                    @b_Success         = @b_Success OUTPUT,   

                    @n_err             = @n_err     OUTPUT,  

                    @c_errmsg          = @c_errmsg  OUTPUT                 

     

               SELECT @n_err = @@ERROR  

     

               IF @n_err <> 0   

               BEGIN  

                  SELECT @n_continue = 3  

                  SELECT @n_err = 63570  

                  SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Insert Into LOADPLANDETAIL Failed. (ispWAVLP07)"  

               END  

            END  

            

            WHILE @@ROWCOUNT > 0

               COMMIT TRAN

            

            FETCH NEXT FROM cur_loadpland INTO @c_OrderKey  

         END  

         CLOSE cur_loadpland  

         DEALLOCATE cur_loadpland  

                                

         COMMIT TRAN TRN_LOAD;

            

         FETCH NEXT FROM cur_LPGroup INTO @c_Storerkey, @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05,   

                         @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10  

      END  

      CLOSE cur_LPGroup  

      DEALLOCATE cur_LPGroup  

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



IF @n_continue = 3 AND @@TRANCOUNT > 0 

BEGIN 

   ROLLBACK TRAN    

END



WHILE @n_StartTranCnt > @@TRANCOUNT

   BEGIN TRAN

  

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

    EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispWAVLP07' 

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