SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  ispWAVLP09                                         */
/* Creation Date:  16-Jun-2023                                          */
/* Copyright: MAERSK                                                    */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  WMS-22784 - TW PMA/PEC wave build load                     */
/*           (copy from ispWAVLP03)                                     */
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
/* PVCS Version: 2.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver  Purposes                                   */
/* 16-Jun-2023 NJOW     1.0  DEVOPS Combine Script                      */
/************************************************************************/
CREATE   PROC [dbo].[ispWAVLP09]
   @c_WaveKey NVARCHAR(10)
 , @b_Success INT           OUTPUT
 , @n_err     INT           OUTPUT
 , @c_errmsg  NVARCHAR(250) OUTPUT
AS
BEGIN

   SET NOCOUNT ON -- SQL 2005 Standard  
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_ConsigneeKey   NVARCHAR(15)
         , @c_Priority       NVARCHAR(10)
         , @c_C_Company      NVARCHAR(45)
         , @c_OrderKey       NVARCHAR(10)
         , @c_Facility       NVARCHAR(5)
         , @c_ExternOrderKey NVARCHAR(50) 
         , @c_StorerKey      NVARCHAR(15)
         , @c_Route          NVARCHAR(10)
         , @c_debug          NVARCHAR(1)
         , @c_loadkey        NVARCHAR(10)
         , @n_continue       INT
         , @n_StartTranCnt   INT
         , @d_OrderDate      DATETIME
         , @d_Delivery_Date  DATETIME
         , @c_OrderType      NVARCHAR(10)
         , @c_Door           NVARCHAR(10)
         , @c_DeliveryPlace  NVARCHAR(30)
         , @c_OrderStatus    NVARCHAR(10)
         , @n_loadcount      INT
         , @n_TotWeight      FLOAT
         , @n_TotCube        FLOAT
         , @n_TotOrdLine     INT

   DECLARE @c_ListName           NVARCHAR(10)
         , @c_Code               NVARCHAR(30) -- e.g. ORDERS01  
         , @c_Description        NVARCHAR(250)
         , @c_TableColumnName    NVARCHAR(250) -- e.g. ORDERS.Orderkey  
         , @c_TableName          NVARCHAR(30)
         , @c_ColumnName         NVARCHAR(30)
         , @c_ColumnType         NVARCHAR(10)
         , @c_SQLField           NVARCHAR(2000)
         , @c_SQLWhere           NVARCHAR(2000)
         , @c_SQLGroup           NVARCHAR(2000)
         , @c_SQLDYN01           NVARCHAR(2000)
         , @c_SQLDYN02           NVARCHAR(2000)
         , @c_SQLDYN03           NVARCHAR(2000)
         , @c_Field01            NVARCHAR(60)
         , @c_Field02            NVARCHAR(60)
         , @c_Field03            NVARCHAR(60)
         , @c_Field04            NVARCHAR(60)
         , @c_Field05            NVARCHAR(60)
         , @c_Field06            NVARCHAR(60)
         , @c_Field07            NVARCHAR(60)
         , @c_Field08            NVARCHAR(60)
         , @c_Field09            NVARCHAR(60)
         , @c_Field10            NVARCHAR(60)
         , @n_cnt                INT
         , @c_FoundLoadkey       NVARCHAR(10)
         , @c_NoOfOrderAllowPTL  NVARCHAR(10)
         , @c_Userdefine01       NVARCHAR(20)
         , @c_DocType            NVARCHAR(1) 
         , @c_SuperOrderFlag     NVARCHAR(1) 
         , @c_DefaultStrategy    NVARCHAR(1) 
         , @n_NoOfGroupField     INT 
         , @c_Load_Userdef1      NVARCHAR(4000) 
         , @c_Authority          NVARCHAR(10) 
         , @n_OrderCnt           INT 
         , @n_MaxOrderPerLoad    INT 
         , @c_OrderSort          NVARCHAR(2000) 
         , @c_IsEcom             NCHAR(1)='N'  
         , @c_CombineOthWaveLoad NVARCHAR(30)='' 
         , @c_WaveType           NVARCHAR(18)
         , @c_MaxOrdPerLoad      NVARCHAR(10) 
         , @c_FinalLocList       NVARCHAR(1000)
         , @n_LastFinalLocSeq    INT = 0
         , @c_FinalLoc           NVARCHAR(10)
         , @n_MaxFinalLoc        INT = 0
         
   DECLARE @n_TablePos     INT
         , @n_TableNameLen INT
         , @n_EndPos1      INT
         , @n_EndPos2      INT
         , @n_EndPos3      INT
         , @n_RtnPos1      INT
         , @n_RtnPos2      INT

   SELECT @n_StartTranCnt = @@TRANCOUNT
        , @n_continue = 1
        , @n_loadcount = 0
        , @n_OrderCnt = 0
        , @n_MaxOrderPerLoad = 99999 
        
   -------------------------- Wave Validation ------------------------------    
   IF NOT EXISTS (  SELECT 1
                    FROM WAVEDETAIL WITH (NOLOCK)
                    WHERE WaveKey = @c_WaveKey)
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 63500
      SELECT @c_errmsg = "NSQL" + CONVERT(NVARCHAR(5), @n_err)
                         + ": No Orders being populated into WaveDetail. (ispWAVLP09)"
      GOTO RETURN_SP
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT TOP 1 @c_StorerKey = StorerKey
                 , @c_Facility = Facility
                 , @c_IsEcom = CASE WHEN OH.DocType = 'E' THEN 'Y' ELSE 'N' END  
      FROM ORDERS OH WITH (NOLOCK)
      JOIN WAVEDETAIL AS WD WITH (NOLOCK) ON WD.OrderKey = OH.OrderKey
      WHERE WD.WaveKey = @c_WaveKey
                                                        
      SELECT @c_CombineOthWaveLoad = dbo.fnc_GetParamValueFromString('@c_CombineOthWaveLoad', SC.Option5, '')
      FROM dbo.fnc_getright2(@c_Facility, @c_Storerkey,'','WAVEGENLOADPLAN') AS SC
      WHERE SC.Authority = 'ispWAVLP09'
      
      IF @c_CombineOthWaveLoad = 'B2B' AND @c_IsEcom = 'N'
         SET @c_CombineOthWaveLoad = 'Y'
      ELSE IF @c_CombineOthWaveLoad = 'B2C' AND @c_IsEcom = 'Y'
         SET @c_CombineOthWaveLoad = 'Y'
      ELSE IF @c_CombineOthWaveLoad <> 'Y'
         SET @c_CombineOthWaveLoad = ''
         
      SELECT @b_Success = 0
      EXECUTE nspGetRight @c_Facility
                        , @c_StorerKey -- Storer
                        , NULL -- No Sku in this Case
                        , 'NoOfOrderAllowPTL' -- ConfigKey
                        , @b_Success OUTPUT
                        , @c_NoOfOrderAllowPTL OUTPUT
                        , @n_err OUTPUT
                        , @c_errmsg OUTPUT

      IF @b_Success <> 1
      BEGIN
         SELECT @n_continue = 3
         GOTO RETURN_SP
      END
      ELSE
      BEGIN
         IF ISNUMERIC(@c_NoOfOrderAllowPTL) = 1
         BEGIN
            IF CAST(@c_NoOfOrderAllowPTL AS INT) > 0
            BEGIN
               SELECT @c_Userdefine01 = UserDefine01
               FROM WAVE (NOLOCK)
               WHERE WaveKey = @c_WaveKey

               IF ISNULL(@c_Userdefine01, '') = ''
               BEGIN
                  SELECT TOP 1 @c_Userdefine01 = CL.Short
                  FROM WAVEDETAIL WD (NOLOCK)
                  JOIN ORDERS O (NOLOCK) ON WD.OrderKey = O.OrderKey
                  JOIN CODELKUP CL (NOLOCK) ON  O.OrderGroup = CL.Code
                                            AND CL.LISTNAME = 'ORDERGROUP'
                                            AND WD.WaveKey = @c_WaveKey
               END

               IF ISNULL(@c_Userdefine01, '') NOT IN ( 'L', 'N', 'E' ) 
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                       , @n_err = 63501 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg = "NSQL" + CONVERT(NVARCHAR(5), @n_err)
                                     + ": Invalid Code to determine Launch or Retail/Wholesale/ECOM Order (ispWAVLP09)"
                  GOTO RETURN_SP
               END

               IF @c_Userdefine01 = 'L'
                  IF (  SELECT COUNT(DISTINCT PICKDETAIL.OrderKey)
                        FROM ORDERS (NOLOCK)
                        JOIN PICKDETAIL (NOLOCK) ON ORDERS.OrderKey = PICKDETAIL.OrderKey
                        WHERE ORDERS.UserDefine09 = @c_WaveKey AND PICKDETAIL.UOM IN ( '6', '7' )) > CAST(@c_NoOfOrderAllowPTL AS INT)
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 63502
                     SELECT @c_errmsg = "NSQL" + CONVERT(NVARCHAR(5), @n_err)
                                        + ": No. of Wave Plan Orders Exceeded PTL Limit " + RTRIM(@c_NoOfOrderAllowPTL)
                                        + " (ispWAVLP09)"
                     GOTO RETURN_SP
                  END
            END
         END
      END
   END

   -------------------------- Construct Load Plan Dynamic Grouping ------------------------------    
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_ListName = CODELIST.LISTNAME,
             @c_WaveType = WAVE.WaveType
      FROM WAVE (NOLOCK)
      JOIN CODELIST (NOLOCK) ON WAVE.LoadplanGroup = CODELIST.LISTNAME AND CODELIST.ListGroup = 'WAVELPGROUP'
      WHERE WAVE.WaveKey = @c_WaveKey

      IF ISNULL(@c_ListName, '') = ''
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63503
         SELECT @c_errmsg = "NSQL" + CONVERT(NVARCHAR(5), @n_err)
                            + ": Empty/Invalid Load Plan Group Is Not Allowed. (LIST GROUP: WAVELPGROUP) (ispWAVLP09)"
         GOTO RETURN_SP
      END

      SELECT TOP 1 @n_MaxOrderPerLoad = CASE WHEN ISNUMERIC(CL.Long) = 1 THEN CAST(CL.Long AS INT)
                                             ELSE 99999 END
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.LISTNAME = @c_ListName AND CL.Code = 'MAXORDER'

      IF ISNULL(@n_MaxOrderPerLoad, 0) = 0
         SET @n_MaxOrderPerLoad = 99999

      SELECT TOP 1 @c_OrderSort = CL.Long
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.LISTNAME = @c_ListName AND CL.Code = 'SORTORDER'

      IF ISNULL(@c_OrderSort, '') <> ''
      BEGIN
         IF LEFT(LTRIM(@c_OrderSort), 8) <> 'ORDER BY'
         BEGIN
            SET @c_OrderSort = N' ORDER BY ' + LTRIM(@c_OrderSort)
         END
      END
      ELSE
      BEGIN
         SET @c_OrderSort = N' ORDER BY ORDERS.OrderKey '
      END
      
      SELECT TOP 1 @c_MaxOrdPerLoad = Short,
                   @c_FinalLocList = Notes,
                   @n_LastFinalLocSeq = CASE WHEN ISNUMERIC(Long) = 1 THEN CAST(Long AS INT) ELSE 0 END
      FROM CODELKUP (NOLOCK)
      WHERE ListName = 'WAVETYPE'
      AND Code = @c_WaveType
      AND Storerkey = @c_Storerkey
      
      IF ISNUMERIC(@c_MaxOrdPerLoad) = 1 AND @c_MaxOrdPerLoad <> '0'
      BEGIN
         SELECT @n_MaxOrderPerLoad = CAST(@c_MaxOrdPerLoad AS INT)
      END      
      
      SELECT @n_MaxFinalLoc = MAX(SeqNo)
      FROM dbo.fnc_DelimSplit(',', @c_FinalLocList)
      
      IF @n_LastFinalLocSeq > @n_MaxFinalLoc
         SET @n_LastFinalLocSeq = 0
         
      DECLARE CUR_CODELKUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT TOP 10 Code
                  , Description
                  , Long
      FROM CODELKUP WITH (NOLOCK)
      WHERE LISTNAME = @c_ListName 
      AND Code NOT IN ( 'MAXORDER', 'SORTORDER' ) 
      ORDER BY Code

      OPEN CUR_CODELKUP

      FETCH NEXT FROM CUR_CODELKUP
      INTO @c_Code
         , @c_Description
         , @c_TableColumnName

      SELECT @c_SQLField = N''
           , @c_SQLWhere = N''
           , @c_SQLGroup = N''
           , @n_cnt = 0
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @n_cnt = @n_cnt + 1

         IF CHARINDEX('(', @c_TableColumnName, 1) > 0 --NJOW04 support field name with function
         BEGIN
            SELECT @c_TableName = N'ORDERS'
            SELECT @n_TableNameLen = LEN(@c_TableName)
            SELECT @n_TablePos = CHARINDEX(@c_TableName, @c_TableColumnName, 1)

            IF @n_TablePos <= 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 63514
               SELECT @c_errmsg = "NSQL" + CONVERT(CHAR(5), @n_err)
                                  + ": Grouping Only Allow Refer To Orders Table's Fields. Invalid Table: "
                                  + RTRIM(@c_TableColumnName) + " (ispWAVLP02)"
               GOTO RETURN_SP
            END

            SELECT @n_EndPos1 = CHARINDEX(',', @c_TableColumnName, @n_TablePos + @n_TableNameLen)
            SELECT @n_EndPos2 = CHARINDEX(')', @c_TableColumnName, @n_TablePos + @n_TableNameLen)
            SELECT @n_EndPos3 = CHARINDEX(' ', @c_TableColumnName, @n_TablePos + @n_TableNameLen)

            IF @n_EndPos1 = 0
               SET @n_RtnPos1 = @n_EndPos2
            ELSE IF @n_EndPos2 = 0
               SET @n_RtnPos1 = @n_EndPos1
            ELSE IF @n_EndPos1 > @n_EndPos2
               SET @n_RtnPos1 = @n_EndPos2
            ELSE
               SET @n_RtnPos1 = @n_EndPos1

            IF @n_RtnPos1 = 0
               SET @n_RtnPos2 = @n_EndPos3
            ELSE IF @n_EndPos3 = 0
               SET @n_RtnPos2 = @n_RtnPos1
            ELSE IF @n_RtnPos1 > @n_EndPos3
               SET @n_RtnPos2 = @n_EndPos3
            ELSE
               SET @n_RtnPos2 = @n_RtnPos1

            IF @n_RtnPos2 > 0 -- +1 is comma  @n_RtnPos2 is position of close symbol ,)
               SELECT @c_ColumnName = RTRIM(
                                         SUBSTRING(
                                            @c_TableColumnName
                                          , @n_TablePos + @n_TableNameLen + 1
                                          , @n_RtnPos2 - (@n_TablePos + @n_TableNameLen + 1)))
            ELSE
               SELECT @c_ColumnName = RTRIM(
                                         SUBSTRING(
                                            @c_TableColumnName
                                          , @n_TablePos + @n_TableNameLen + 1
                                          , LEN(@c_TableColumnName)))
         END
         ELSE
         BEGIN
            SET @c_TableName = LEFT(@c_TableColumnName, CHARINDEX('.', @c_TableColumnName) - 1)
            SET @c_ColumnName = SUBSTRING(
                                   @c_TableColumnName
                                 , CHARINDEX('.', @c_TableColumnName) + 1
                                 , LEN(@c_TableColumnName) - CHARINDEX('.', @c_TableColumnName))

            IF ISNULL(RTRIM(@c_TableName), '') <> 'ORDERS'
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 63504
               SELECT @c_errmsg = "NSQL" + CONVERT(NVARCHAR(5), @n_err)
                                  + ": Grouping Only Allow Refer To Orders Table's Fields. Invalid Table: "
                                  + RTRIM(@c_TableColumnName) + " (ispWAVLP09)"
               GOTO RETURN_SP
            END
         END

         SET @c_ColumnType = N''
         SELECT @c_ColumnType = DATA_TYPE
         FROM INFORMATION_SCHEMA.COLUMNS
         WHERE TABLE_NAME = @c_TableName AND COLUMN_NAME = @c_ColumnName

         IF ISNULL(RTRIM(@c_ColumnType), '') = ''
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63505
            SELECT @c_errmsg = "NSQL" + CONVERT(NVARCHAR(5), @n_err) + ": Invalid Column Name: "
                               + RTRIM(@c_TableColumnName) + ". (ispWAVLP09)"
            GOTO RETURN_SP
         END

         IF @c_ColumnType IN ( 'float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint', 'text' )
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63506
            SELECT @c_errmsg = "NSQL" + CONVERT(NVARCHAR(5), @n_err)
                               + ": Numeric/Text Column Type Is Not Allowed For Load Plan Grouping: "
                               + RTRIM(@c_TableColumnName) + ". (ispWAVLP09)"
            GOTO RETURN_SP
         END

         IF @c_ColumnType IN ( 'char', 'nvarchar', 'varchar', 'nchar' ) 
         BEGIN
            SELECT @c_SQLField = @c_SQLField + N',' + RTRIM(@c_TableColumnName)
            SELECT @c_SQLWhere = @c_SQLWhere + N' AND ' + RTRIM(@c_TableColumnName) + N'='
                                 + CASE WHEN @n_cnt = 1 THEN '@c_Field01'
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

         IF @c_ColumnType IN ( 'datetime' ) 
         BEGIN
            SELECT @c_SQLField = @c_SQLField + N', CONVERT(NVARCHAR(10),' + RTRIM(@c_TableColumnName) + N',112)'
            SELECT @c_SQLWhere = @c_SQLWhere + N' AND CONVERT(NVARCHAR(10),' + RTRIM(@c_TableColumnName) + N',112)='
                                 + CASE WHEN @n_cnt = 1 THEN '@c_Field01'
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

         FETCH NEXT FROM CUR_CODELKUP
         INTO @c_Code
            , @c_Description
            , @c_TableColumnName
      END
      CLOSE CUR_CODELKUP
      DEALLOCATE CUR_CODELKUP

      SELECT @n_NoOfGroupField = @n_cnt 
      
      SELECT @c_SQLGroup = @c_SQLField
      WHILE @n_cnt < 10
      BEGIN
         SET @n_cnt = @n_cnt + 1
         SELECT @c_SQLField = @c_SQLField + N','''''

         SELECT @c_SQLWhere = @c_SQLWhere + N' AND ''''=' + CASE WHEN @n_cnt = 1 THEN 'ISNULL(@c_Field01,'''')'
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
      SELECT @c_SQLDYN01 = N'DECLARE cur_LPGroup CURSOR FAST_FORWARD READ_ONLY FOR ' + N' SELECT ORDERS.Storerkey '
                           + @c_SQLField + N' FROM ORDERS WITH (NOLOCK) '
                           + N' JOIN WaveDetail WD WITH (NOLOCK) ON (ORDERS.OrderKey = WD.OrderKey) '
                           + N'  WHERE WD.WaveKey = ''' + RTRIM(@c_WaveKey) + N''''
                           + N' AND ISNULL(ORDERS.Loadkey,'''') = '''' '
                           + N' AND ORDERS.Status NOT IN (''9'',''CANC'') ' + N' GROUP BY ORDERS.Storerkey '
                           + @c_SQLGroup + N' ORDER BY ORDERS.Storerkey ' + @c_SQLGroup

      EXEC (@c_SQLDYN01)

      OPEN cur_LPGroup
      FETCH NEXT FROM cur_LPGroup
      INTO @c_StorerKey
         , @c_Field01
         , @c_Field02
         , @c_Field03
         , @c_Field04
         , @c_Field05
         , @c_Field06
         , @c_Field07
         , @c_Field08
         , @c_Field09
         , @c_Field10
      WHILE @@FETCH_STATUS = 0
      BEGIN
         BEGIN TRAN TRN_LOAD;

         --WL01 S
         SET @n_OrderCnt = 0

         SELECT @n_cnt = 1
              , @c_Load_Userdef1 = N''

         WHILE @n_cnt <= @n_NoOfGroupField
         BEGIN
            SELECT @c_Load_Userdef1 = @c_Load_Userdef1
                                      + CASE WHEN @n_cnt = 1 THEN LTRIM(RTRIM(ISNULL(@c_Field01, '')))
                                             WHEN @n_cnt = 2 THEN '-' + LTRIM(RTRIM(ISNULL(@c_Field02, '')))
                                             WHEN @n_cnt = 3 THEN '-' + LTRIM(RTRIM(ISNULL(@c_Field03, '')))
                                             WHEN @n_cnt = 4 THEN '-' + LTRIM(RTRIM(ISNULL(@c_Field04, '')))
                                             WHEN @n_cnt = 5 THEN '-' + LTRIM(RTRIM(ISNULL(@c_Field05, '')))
                                             WHEN @n_cnt = 6 THEN '-' + LTRIM(RTRIM(ISNULL(@c_Field06, '')))
                                             WHEN @n_cnt = 7 THEN '-' + LTRIM(RTRIM(ISNULL(@c_Field07, '')))
                                             WHEN @n_cnt = 8 THEN '-' + LTRIM(RTRIM(ISNULL(@c_Field08, '')))
                                             WHEN @n_cnt = 9 THEN '-' + LTRIM(RTRIM(ISNULL(@c_Field09, '')))
                                             WHEN @n_cnt = 10 THEN '-' + LTRIM(RTRIM(ISNULL(@c_Field10, '')))END

            SET @n_cnt = @n_cnt + 1
         END

         SET @c_FoundLoadkey = N''

         SELECT @c_SQLDYN03 = N' SELECT TOP 1 @c_FoundLoadkey = ORDERS.Loadkey ' + N' FROM ORDERS WITH (NOLOCK) '
                              + N' JOIN WaveDetail WD WITH (NOLOCK) ON (ORDERS.OrderKey = WD.OrderKey) '
                              + N' WHERE  ORDERS.StorerKey = @c_StorerKey ' + N' AND WD.WaveKey = @c_WaveKey '
                              + N' AND ORDERS.Status NOT IN (''9'',''CANC'') '
                              + N' AND ISNULL(ORDERS.Loadkey,'''') <> '''' ' + @c_SQLWhere
                              + N' ORDER BY ORDERS.Loadkey DESC '

         EXEC sp_executesql @c_SQLDYN03
                          , N'@c_Storerkey NVARCHAR(15), @c_Wavekey NVARCHAR(10), @c_Field01 NVARCHAR(60), @c_Field02 NVARCHAR(60),@c_Field03 NVARCHAR(60),@c_Field04 NVARCHAR(60),  
                              @c_Field05 NVARCHAR(60), @c_Field06 NVARCHAR(60), @c_Field07 NVARCHAR(60), @c_Field08 NVARCHAR(60), @c_Field09 NVARCHAR(60), @c_Field10 NVARCHAR(60), @c_FoundLoadkey NVARCHAR(10) OUTPUT'
                          , @c_StorerKey
                          , @c_WaveKey
                          , @c_Field01
                          , @c_Field02
                          , @c_Field03
                          , @c_Field04
                          , @c_Field05
                          , @c_Field06
                          , @c_Field07
                          , @c_Field08
                          , @c_Field09
                          , @c_Field10
                          , @c_FoundLoadkey OUTPUT

         IF  ISNULL(@c_FoundLoadkey, '') <> ''
         AND (NOT EXISTS ( SELECT 1
                           FROM ORDERS (NOLOCK)
                           WHERE LoadKey = @c_FoundLoadkey AND ISNULL(LoadKey, '') <> '' AND UserDefine09 <> @c_WaveKey) 
              OR @c_CombineOthWaveLoad = 'Y'  
              )             
         BEGIN        
            SET @c_loadkey = @c_FoundLoadkey
            SELECT @n_loadcount = @n_loadcount + 1  
            
            SELECT @n_OrderCnt = COUNT(1)
            FROM LOADPLANDETAIL (NOLOCK)
            WHERE Loadkey = @c_Loadkey
         END
         ELSE 
         BEGIN
            SELECT @c_SuperOrderFlag = N'N'
                 , @c_DefaultStrategy = N'N'
                 , @c_DocType = N''
                 , @c_Facility = N''

            SELECT @n_loadcount = @n_loadcount + 1

            SELECT TOP 1 @c_Facility = OH.Facility 
                       , @c_DocType = OH.DocType
            FROM ORDERS OH WITH (NOLOCK) 
            JOIN WAVEDETAIL AS WD WITH (NOLOCK) ON WD.OrderKey = OH.OrderKey             
            WHERE WD.WaveKey = @c_WaveKey  
            AND OH.Storerkey = @c_StorerKey  
            AND OH.Status NOT IN ('9','CANC')  
            AND (OH.Loadkey = '' OR OH.LoadKey IS NULL)   

            SELECT @c_Authority = N''
                 , @b_Success = 0
            EXECUTE nspGetRight @c_Facility
                              , @c_StorerKey -- Storer
                              , NULL -- Sku
                              , 'AutoUpdSupOrdflag' -- ConfigKey
                              , @b_Success OUTPUT
                              , @c_Authority OUTPUT
                              , @n_err OUTPUT
                              , @c_errmsg OUTPUT

            IF @b_Success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = 'ispWAVLP09:' + RTRIM(ISNULL(@c_errmsg, ''))
            END
            ELSE IF @c_Authority = '1'
            BEGIN
               SELECT @c_SuperOrderFlag = N'Y'
            END

            IF @c_DocType = 'E'
            BEGIN
               SELECT @c_Authority = N''
                    , @b_Success = 0
               EXECUTE nspGetRight @c_Facility
                                 , @c_StorerKey -- Storer
                                 , NULL -- Sku
                                 , 'GenEcomLPSetSuperOrderFlag' -- ConfigKey
                                 , @b_Success OUTPUT
                                 , @c_Authority OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT

               IF @b_Success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = 'ispWAVLP09:' + RTRIM(ISNULL(@c_errmsg, ''))
               END
               ELSE IF @c_Authority = '1'
               BEGIN
                  SELECT @c_SuperOrderFlag = N'Y'
               END

               SELECT @c_Authority = N''
                    , @b_Success = 0
               EXECUTE nspGetRight @c_Facility
                                 , @c_StorerKey -- Storer
                                 , NULL -- Sku
                                 , 'GenEcomLPSetDefaultStrategy' -- ConfigKey
                                 , @b_Success OUTPUT
                                 , @c_Authority OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT

               IF @b_Success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = 'ispWAVLP09:' + RTRIM(ISNULL(@c_errmsg, ''))
               END
               ELSE IF @c_Authority = '1'
               BEGIN
                  SELECT @c_DefaultStrategy = N'Y'
               END
            END

            SELECT @b_Success = 0
            EXECUTE nspg_GetKey 'LOADKEY'
                              , 10
                              , @c_loadkey OUTPUT
                              , @b_Success OUTPUT
                              , @n_err OUTPUT
                              , @c_errmsg OUTPUT

            IF @b_Success <> 1
            BEGIN
               SELECT @n_continue = 3
            END
            
            SET @c_FinalLoc = ''
            
            IF @n_MaxFinalLoc > 0
            BEGIN
               SELECT @n_LastFinalLocSeq = @n_LastFinalLocSeq + 1
               
               IF @n_LastFinalLocSeq > @n_MaxFinalLoc 
                  SET @n_LastFinalLocSeq = 1
                  
               SELECT @c_FinalLoc = RTRIM(LTRIM(ColValue))
               FROM dbo.fnc_DelimSplit(',',@c_FinalLocList)
               WHERE SeqNo = @n_LastFinalLocSeq            
            END
                        
            INSERT INTO LoadPlan (LoadKey, facility, UserDefine09, SuperOrderFlag, DefaultStrategykey, Load_Userdef1, TrfRoom)
            VALUES (@c_loadkey, @c_Facility, @c_WaveKey, @c_SuperOrderFlag, @c_DefaultStrategy, @c_Load_Userdef1, @c_FinalLoc)

            SELECT @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 63560
               SELECT @c_errmsg = "NSQL" + CONVERT(NVARCHAR(5), @n_err) + ": Insert Into LOADPLAN Failed. (ispWAVLP09)"
            END
         END

         -- Create loadplan detail  

         SELECT @c_SQLDYN02 = N'DECLARE cur_loadpland CURSOR FAST_FORWARD READ_ONLY FOR ' + N' SELECT ORDERS.OrderKey '
                              + N' FROM ORDERS WITH (NOLOCK) '
                              + N' JOIN WaveDetail WD WITH (NOLOCK) ON (ORDERS.OrderKey = WD.OrderKey) '
                              + N' WHERE  ORDERS.StorerKey = @c_StorerKey ' + +N' AND WD.WaveKey = @c_WaveKey '
                              + N' AND ORDERS.Status NOT IN (''9'',''CANC'') '
                              + N' AND ISNULL(ORDERS.Loadkey,'''') = '''' ' 
                              + @c_SQLWhere 
                              + @c_OrderSort --WL01
         --+ ' ORDER BY ORDERS.OrderKey '  

         EXEC sp_executesql @c_SQLDYN02
                          , N'@c_Storerkey NVARCHAR(15), @c_Wavekey NVARCHAR(10), @c_Field01 NVARCHAR(60), @c_Field02 NVARCHAR(60),@c_Field03 NVARCHAR(60),@c_Field04 NVARCHAR(60),  
                              @c_Field05 NVARCHAR(60), @c_Field06 NVARCHAR(60), @c_Field07 NVARCHAR(60), @c_Field08 NVARCHAR(60), @c_Field09 NVARCHAR(60), @c_Field10 NVARCHAR(60)'
                          , @c_StorerKey
                          , @c_WaveKey
                          , @c_Field01
                          , @c_Field02
                          , @c_Field03
                          , @c_Field04
                          , @c_Field05
                          , @c_Field06
                          , @c_Field07
                          , @c_Field08
                          , @c_Field09
                          , @c_Field10

         OPEN cur_loadpland

         FETCH NEXT FROM cur_loadpland
         INTO @c_OrderKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            --WL01 S
            SET @n_OrderCnt = @n_OrderCnt + 1

            IF @n_OrderCnt > @n_MaxOrderPerLoad OR @n_loadcount = 0
            BEGIN
               SELECT @c_SuperOrderFlag = N'N'
                    , @c_DefaultStrategy = N'N'
                    , @c_DocType = N''
                    , @c_Facility = N''
                    , @n_OrderCnt = 1

               SELECT @n_loadcount = @n_loadcount + 1

               SELECT @c_Facility = ORDERS.Facility
                    , @c_DocType = ORDERS.DocType
                    , @c_StorerKey = ORDERS.StorerKey
               FROM ORDERS (NOLOCK)
               WHERE ORDERS.OrderKey = @c_OrderKey

               SELECT @c_Authority = N''
                    , @b_Success = 0
               EXECUTE nspGetRight @c_Facility
                                 , @c_StorerKey -- Storer
                                 , NULL -- Sku
                                 , 'AutoUpdSupOrdflag' -- ConfigKey
                                 , @b_Success OUTPUT
                                 , @c_Authority OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT

               IF @b_Success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = 'ispWAVLP09:' + RTRIM(ISNULL(@c_errmsg, ''))
               END
               ELSE IF @c_Authority = '1'
               BEGIN
                  SELECT @c_SuperOrderFlag = N'Y'
               END

               IF @c_DocType = 'E'
               BEGIN
                  SELECT @c_Authority = N''
                       , @b_Success = 0
                  EXECUTE nspGetRight @c_Facility
                                    , @c_StorerKey -- Storer
                                    , NULL -- Sku
                                    , 'GenEcomLPSetSuperOrderFlag' -- ConfigKey
                                    , @b_Success OUTPUT
                                    , @c_Authority OUTPUT
                                    , @n_err OUTPUT
                                    , @c_errmsg OUTPUT

                  IF @b_Success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = 'ispWAVLP09:' + RTRIM(ISNULL(@c_errmsg, ''))
                  END
                  ELSE IF @c_Authority = '1'
                  BEGIN
                     SELECT @c_SuperOrderFlag = N'Y'
                  END

                  SELECT @c_Authority = N''
                       , @b_Success = 0
                  EXECUTE nspGetRight @c_Facility
                                    , @c_StorerKey -- Storer
                                    , NULL -- Sku
                                    , 'GenEcomLPSetDefaultStrategy' -- ConfigKey
                                    , @b_Success OUTPUT
                                    , @c_Authority OUTPUT
                                    , @n_err OUTPUT
                                    , @c_errmsg OUTPUT

                  IF @b_Success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = 'ispWAVLP09:' + RTRIM(ISNULL(@c_errmsg, ''))
                  END
                  ELSE IF @c_Authority = '1'
                  BEGIN
                     SELECT @c_DefaultStrategy = N'Y'
                  END
               END

               SELECT @b_Success = 0
               EXECUTE nspg_GetKey 'LOADKEY'
                                 , 10
                                 , @c_loadkey OUTPUT
                                 , @b_Success OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT

               IF @b_Success <> 1
               BEGIN
                  SELECT @n_continue = 3
               END

               SET @c_FinalLoc = ''
            
               IF @n_MaxFinalLoc > 0
               BEGIN
                  SELECT @n_LastFinalLocSeq = @n_LastFinalLocSeq + 1
                  
                  IF @n_LastFinalLocSeq > @n_MaxFinalLoc 
                     SET @n_LastFinalLocSeq = 1
                     
                  SELECT @c_FinalLoc = RTRIM(LTRIM(ColValue))
                  FROM dbo.fnc_DelimSplit(',',@c_FinalLocList)
                  WHERE SeqNo = @n_LastFinalLocSeq            
               END

               INSERT INTO LoadPlan (LoadKey, facility, UserDefine09, SuperOrderFlag, DefaultStrategykey, Load_Userdef1, TrfRoom)
               VALUES (@c_loadkey, @c_Facility, @c_WaveKey, @c_SuperOrderFlag, @c_DefaultStrategy, @c_Load_Userdef1, @c_FinalLoc)

               SELECT @n_err = @@ERROR

               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 63560
                  SELECT @c_errmsg = "NSQL" + CONVERT(NVARCHAR(5), @n_err)
                                     + ": Insert Into LOADPLAN Failed. (ispWAVLP09)"
               END
            END

            IF (  SELECT COUNT(1)
                  FROM LoadPlanDetail WITH (NOLOCK)
                  WHERE OrderKey = @c_OrderKey) = 0
            BEGIN
               SELECT @d_OrderDate = O.OrderDate
                    , @d_Delivery_Date = O.DeliveryDate
                    , @c_OrderType = O.Type
                    , @c_Door = O.Door
                    , @c_Route = O.Route
                    , @c_DeliveryPlace = O.DeliveryPlace
                    , @c_OrderStatus = O.Status
                    , @c_Priority = O.Priority
                    , @n_TotWeight = SUM(OD.OpenQty * SKU.STDGROSSWGT)
                    , @n_TotCube = SUM(OD.OpenQty * SKU.STDCUBE)
                    , @n_TotOrdLine = COUNT(DISTINCT OD.OrderLineNumber)
                    , @c_C_Company = O.C_Company
                    , @c_ExternOrderKey = O.ExternOrderKey
                    , @c_ConsigneeKey = O.ConsigneeKey
               FROM ORDERS O WITH (NOLOCK)
               JOIN ORDERDETAIL OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey)
               JOIN SKU WITH (NOLOCK) ON (OD.StorerKey = SKU.StorerKey AND OD.Sku = SKU.Sku)
               WHERE O.OrderKey = @c_OrderKey
               GROUP BY O.OrderDate
                      , O.DeliveryDate
                      , O.Type
                      , O.Door
                      , O.Route
                      , O.DeliveryPlace
                      , O.Status
                      , O.Priority
                      , O.C_Company
                      , O.ExternOrderKey
                      , O.ConsigneeKey

               EXEC isp_InsertLoadplanDetail @cLoadKey = @c_loadkey
                                           , @cFacility = @c_Facility
                                           , @cOrderKey = @c_OrderKey
                                           , @cConsigneeKey = @c_ConsigneeKey
                                           , @cPrioriry = @c_Priority
                                           , @dOrderDate = @d_OrderDate
                                           , @dDelivery_Date = @d_Delivery_Date
                                           , @cOrderType = @c_OrderType
                                           , @cDoor = @c_Door
                                           , @cRoute = @c_Route
                                           , @cDeliveryPlace = @c_DeliveryPlace
                                           , @nStdGrossWgt = @n_TotWeight
                                           , @nStdCube = @n_TotCube
                                           , @cExternOrderKey = @c_ExternOrderKey
                                           , @cCustomerName = @c_C_Company
                                           , @nTotOrderLines = @n_TotOrdLine
                                           , @nNoOfCartons = 0
                                           , @cOrderStatus = @c_OrderStatus --(Wan02)          
                                           , @b_Success = @b_Success OUTPUT
                                           , @n_Err = @n_err OUTPUT
                                           , @c_ErrMsg = @c_errmsg OUTPUT

               SELECT @n_err = @@ERROR

               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 63508
                  SELECT @c_errmsg = "NSQL" + CONVERT(NVARCHAR(5), @n_err)
                                     + ": Insert Into LOADPLANDETAIL Failed. (ispWAVLP09)"
                  GOTO RETURN_SP
               END
            END

            WHILE @@ROWCOUNT > 0
               COMMIT TRAN

            FETCH NEXT FROM cur_loadpland
            INTO @c_OrderKey
         END
         CLOSE cur_loadpland
         DEALLOCATE cur_loadpland

         COMMIT TRAN TRN_LOAD;

         FETCH NEXT FROM cur_LPGroup
         INTO @c_StorerKey
            , @c_Field01
            , @c_Field02
            , @c_Field03
            , @c_Field04
            , @c_Field05
            , @c_Field06
            , @c_Field07
            , @c_Field08
            , @c_Field09
            , @c_Field10
      END
      CLOSE cur_LPGroup
      DEALLOCATE cur_LPGroup
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @n_loadcount > 0
      BEGIN
      	 IF @n_LastFinalLocSeq > 0
      	 BEGIN
            UPDATE CODELKUP WITH (ROWLOCK)
            SET Long = CAST(@n_LastFinalLocSeq AS NVARCHAR)
            WHERE ListName = 'WAVETYPE'
            AND Code = @c_WaveType
            AND Storerkey = @c_Storerkey      
         END
      	 
         SELECT @c_errmsg = RTRIM(CAST(@n_loadcount AS CHAR)) + ' Load Plan Generated'
      END   
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
    EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispWAVLP09' 
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