SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store Procedure:  ispWAVLP04                                         */
/* Creation Date:  04-Feb-2014                                          */
/* Copyright: IDS                                                       */
/* Written by:  YTWan                                                   */
/*                                                                      */
/* Purpose:  SOS#301160 - [Adidas] Create New Wave Generate Load Plan   */
/*           by Group                                                   */
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
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver  Purposes                                   */
/* 13-Apr-2014 TLTING   1.1  SQL2012                                    */
/* 05-Mar-2015 TLTING01 1.2  Blocking issue                             */
/* 27-Jun-2018 NJOW01   1.3  Fix - include NCHAR                        */
/* 28-Jan-2019 TLTING_ext 1.4  enlarge externorderkey field length     */
/************************************************************************/
CREATE PROC [dbo].[ispWAVLP04]
   @c_WaveKey NVARCHAR(10),
   @b_Success int OUTPUT,
   @n_err     int OUTPUT,
   @c_errmsg  NVARCHAR(250) OUTPUT
AS
BEGIN

   SET NOCOUNT ON   -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @c_ConsigneeKey      NVARCHAR( 15)
         ,  @c_Priority          NVARCHAR( 10)
         ,  @c_C_Company         NVARCHAR( 45)
         ,  @c_OrderKey          NVARCHAR( 10)
         ,  @c_Facility          NVARCHAR( 5)
         ,  @c_ExternOrderKey    NVARCHAR( 50)   --tlting_ext -- Purchase Order Number
         ,  @c_StorerKey         NVARCHAR( 15)
         ,  @c_Route             NVARCHAR( 10)
         ,  @c_debug             NVARCHAR( 1)
         ,  @c_loadkey           NVARCHAR( 10)
         ,  @n_continue          INT
         ,  @n_StartTranCnt      INT
         ,  @d_OrderDate         DATETIME
         ,  @d_Delivery_Date     DATETIME
         ,  @c_OrderType         NVARCHAR( 10)
         ,  @c_Door              NVARCHAR( 10)
         ,  @c_DeliveryPlace     NVARCHAR( 30)
         ,  @c_OrderStatus       NVARCHAR( 10)
         ,  @n_loadcount         INT
         ,  @n_TotWeight         FLOAT
         ,  @n_TotCube           FLOAT
         ,  @n_TotOrdLine        INT
         ,  @c_Authority         VARCHAR(10)

   DECLARE  @c_ListName          NVARCHAR(10)
         ,  @c_Code              NVARCHAR(30)   -- e.g. ORDERS01
         ,  @c_Description       NVARCHAR(250)
         ,  @c_TableColumnName   NVARCHAR(250)  -- e.g. ORDERS.Orderkey
         ,  @c_TableName         NVARCHAR(30)
         ,  @c_ColumnName        NVARCHAR(30)
         ,  @c_ColumnType        NVARCHAR(10)
         ,  @c_SQLField          NVARCHAR(2000)
         ,  @c_SQLWhere          NVARCHAR(2000)
         ,  @c_SQLGroup          NVARCHAR(2000)
         ,  @c_SQLDYN01          NVARCHAR(2000)
         ,  @c_SQLDYN02          NVARCHAR(2000)
         ,  @c_SQLDYN03          NVARCHAR(2000)  
         ,  @c_Field01           NVARCHAR(60)
         ,  @c_Field02           NVARCHAR(60)
         ,  @c_Field03           NVARCHAR(60)
         ,  @c_Field04           NVARCHAR(60)
         ,  @c_Field05           NVARCHAR(60)
         ,  @c_Field06           NVARCHAR(60)
         ,  @c_Field07           NVARCHAR(60)
         ,  @c_Field08           NVARCHAR(60)
         ,  @c_Field09           NVARCHAR(60)
         ,  @c_Field10           NVARCHAR(60)
         ,  @n_cnt int
         ,  @c_FoundLoadkey      NVARCHAR(10)  

   SET @n_StartTranCnt  =  @@TRANCOUNT
   SET @n_continue      =  1
   SET @n_loadcount     =  0

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END
-------------------------- Wave Validation ------------------------------
   IF NOT EXISTS(SELECT 1 FROM WAVEDETAIL WITH (NOLOCK)
                 WHERE WaveKey = @c_WaveKey)
   BEGIN
      SET @n_continue = 3
      SET @n_err = 63501
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': No Orders being populated into WAVEDETAIL. (ispWAVLP04)'
      GOTO RETURN_SP
   END

-------------------------- Construct Load Plan Dynamic Grouping ------------------------------
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_listname = CODELIST.Listname
      FROM WAVE (NOLOCK)
      JOIN CODELIST (NOLOCK) ON WAVE.LoadPlanGroup = CODELIST.Listname AND CODELIST.ListGroup = 'WAVELPGROUP'
      WHERE WAVE.Wavekey = @c_WaveKey

      IF ISNULL(@c_ListName,'') = ''
      BEGIN
         SET @n_continue = 3
         SET @n_err = 63502
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Empty/Invalid Load Plan Group Is Not Allowed. (LIST GROUP: WAVELPGROUP) (ispWAVLP04)'
         GOTO RETURN_SP
      END

      DECLARE CUR_CODELKUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT TOP 10 Code, Description, Long
      FROM   CODELKUP WITH (NOLOCK)
      WHERE  ListName = @c_ListName
      ORDER BY Code

      OPEN CUR_CODELKUP

      FETCH NEXT FROM CUR_CODELKUP INTO @c_Code, @c_Description, @c_TableColumnName

      SET @c_SQLField = ''
      SET @c_SQLWhere = ''
      SET @c_SQLGroup = ''
      SET @n_cnt      = 0
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @n_cnt = @n_cnt + 1
         SET @c_TableName  = LEFT(@c_TableColumnName, CharIndex('.', @c_TableColumnName) - 1)
         SET @c_ColumnName = SUBSTRING(@c_TableColumnName,
                             CharIndex('.', @c_TableColumnName) + 1, LEN(@c_TableColumnName) - CharIndex('.', @c_TableColumnName))

         IF ISNULL(RTRIM(@c_TableName), '') NOT IN( 'ORDERS', 'SKU' )
         BEGIN
            SET @n_continue = 3
            SET @n_err = 63503
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Grouping Only Allow Refer To Orders Table''s Fields. Invalid Table: '+RTRIM(@c_TableColumnName)+' (ispWAVLP04)'
            GOTO RETURN_SP
         END

         SET @c_ColumnType = ''
         SELECT @c_ColumnType = DATA_TYPE
         FROM   INFORMATION_SCHEMA.COLUMNS
         WHERE  TABLE_NAME = @c_TableName
         AND    COLUMN_NAME = @c_ColumnName
         
         IF ISNULL(RTRIM(@c_ColumnType), '') = ''
         BEGIN
            SET @n_continue = 3
            SET @n_err = 63504
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Invalid Column Name: ' + RTRIM(@c_TableColumnName)+ '. (ispWAVLP04)'
            GOTO RETURN_SP
         END

         IF @c_ColumnType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint','text')
         BEGIN
            SET @n_continue = 3
            SET @n_err = 63505
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Numeric/Text Column Type Is Not Allowed For Load Plan Grouping: ' + RTRIM(@c_TableColumnName)+ '. (ispWAVLP04)'
            GOTO RETURN_SP
         END

         IF @c_ColumnType IN ('char', 'nvarchar', 'varchar','nchar')  --NJOW01
         BEGIN
            SET @c_SQLField = @c_SQLField + ',' + RTRIM(@c_TableColumnName)
            SET @c_SQLWhere = @c_SQLWhere + ' AND ' + RTRIM(@c_TableColumnName) + '=' +
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
            SET @c_SQLField = @c_SQLField + ', CONVERT(VARCHAR(10),' + RTRIM(@c_TableColumnName) + ',112)'
            SET @c_SQLWhere = @c_SQLWhere + ' AND CONVERT(VARCHAR(10),' + RTRIM(@c_TableColumnName) + ',112)=' +
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
      
      SELECT @c_SQLGroup = @c_SQLField
      WHILE @n_cnt < 10
      BEGIN
         SET @n_cnt = @n_cnt + 1
         SET @c_SQLField = @c_SQLField + ','''''
         
         SET @c_SQLWhere = @c_SQLWhere + ' AND ''''=' +
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

   BEGIN TRAN

-------------------------- CREATE LOAD PLAN ------------------------------

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SET @c_SQLDYN01 = 'DECLARE cur_LPGroup CURSOR FAST_FORWARD READ_ONLY FOR '
      + ' SELECT ORDERS.Storerkey ' + @c_SQLField
      + ' FROM ORDERS WITH (NOLOCK) '
      + ' JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey) '
      + ' JOIN WAVEDETAIL WD WITH (NOLOCK) ON (ORDERS.OrderKey = WD.OrderKey) '
      + ' JOIN SKU WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey) AND (ORDERDETAIL.Sku = SKU.Sku) '
      + ' WHERE WD.WaveKey = ''' +  RTRIM(@c_WaveKey) +''''
      + ' AND ISNULL(ORDERS.Loadkey,'''') = '''' '
      + ' AND ORDERS.Status NOT IN (''9'',''CANC'') '
      + ' GROUP BY ORDERS.Storerkey ' + @c_SQLGroup
      + ' ORDER BY ORDERS.Storerkey ' + @c_SQLGroup

      EXEC (@c_SQLDYN01)

      OPEN cur_LPGroup
      FETCH NEXT FROM cur_LPGroup INTO @c_Storerkey, @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05,
                                       @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @c_SQLDYN03 = ' SELECT @c_FoundLoadkey = MAX(ORDERS.Loadkey) '
                         + ' FROM ORDERS WITH (NOLOCK) '
                         + ' JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey) '
                         + ' JOIN WAVEDETAIL WD WITH (NOLOCK) ON (ORDERS.OrderKey = WD.OrderKey) '
                         + ' JOIN SKU WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey) AND (ORDERDETAIL.Sku = SKU.Sku) '
                         + ' WHERE  ORDERS.StorerKey = @c_StorerKey '
                         + ' AND WD.WaveKey = @c_WaveKey '
                         + ' AND ORDERS.Status NOT IN (''9'',''CANC'') '
                         + ' AND ISNULL(ORDERS.Loadkey,'''') <> '''' '
                         + @c_SQLWhere

         EXEC sp_executesql @c_SQLDYN03
                  ,N'@c_Storerkey NVARCHAR(15)
                  ,  @c_Wavekey NVARCHAR(10)
                  ,  @c_Field01 NVARCHAR(60)
                  ,  @c_Field02 NVARCHAR(60)
                  ,  @c_Field03 NVARCHAR(60)
                  ,  @c_Field04 NVARCHAR(60) 
                  ,  @c_Field05 NVARCHAR(60)
                  ,  @c_Field06 NVARCHAR(60)
                  ,  @c_Field07 NVARCHAR(60) 
                  ,  @c_Field08 NVARCHAR(60)
                  ,  @c_Field09 NVARCHAR(60)
                  ,  @c_Field10 NVARCHAR(60)
                  ,  @c_FoundLoadkey NVARCHAR(10) OUTPUT'
                  ,  @c_Storerkey 
                  ,  @c_Wavekey 
                  ,  @c_Field01 
                  ,  @c_Field02 
                  ,  @c_Field03 
                  ,  @c_Field04 
                  ,  @c_Field05 
                  ,  @c_Field06 
                  ,  @c_Field07 
                  ,  @c_Field08 
                  ,  @c_Field09 
                  ,  @c_Field10 
                  ,  @c_FoundLoadkey OUTPUT
         
         IF ISNULL(@c_FoundLoadkey,'') <> ''  
         BEGIN
            SET @c_loadkey = @c_FoundLoadkey
         
            SELECT @c_Facility = MAX(Facility)
            FROM Orders WITH (NOLOCK)
            WHERE ISNULL(Loadkey,'') = @c_loadkey   
         END
         ELSE
         BEGIN
            SEt @b_success = 0
            EXECUTE nspg_GetKey
               'LOADKEY',
               10,
               @c_loadkey     OUTPUT,
               @b_success     OUTPUT,
               @n_err         OUTPUT,
               @c_errmsg      OUTPUT

            IF @b_success <> 1
            BEGIN
               SET @n_continue = 3
               GOTO RETURN_SP
            END
            
            SELECT @c_Facility = MAX(Facility)
            FROM Orders WITH (NOLOCK)
            WHERE Userdefine09 = @c_WaveKey
            AND Storerkey = @c_StorerKey
            AND Status NOT IN ('9','CANC')
            AND ISNULL(Loadkey,'') = ''

            -- Create loadplan
            INSERT INTO LoadPlan (LoadKey, Facility)
            VALUES (@c_loadkey, @c_Facility)

            SET @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_err = 63507
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into LOADPLAN Failed. (ispWAVLP04)'
               GOTO RETURN_SP
            END
         END

         -- tlting01 - 
         WHILE @@TRANCOUNT > 0
         BEGIN
            COMMIT TRAN
         END
         
         BEGIN TRAN  
         
         SELECT @n_loadcount = @n_loadcount + 1

         -- Create loadplan detail

         SET @c_SQLDYN02 = 'DECLARE cur_loadpland CURSOR FAST_FORWARD READ_ONLY FOR '
                         + ' SELECT ORDERS.OrderKey '
                         + ' FROM ORDERS WITH (NOLOCK) '
                         + ' JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey) '
                         + ' JOIN WAVEDETAIL WD WITH (NOLOCK) ON (ORDERS.OrderKey = WD.OrderKey) '
                         + ' JOIN SKU WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey) AND (ORDERDETAIL.Sku = SKU.Sku) '
                         + ' WHERE  ORDERS.StorerKey = @c_StorerKey ' +
                         + ' AND WD.WaveKey = @c_WaveKey '
                         + ' AND ORDERS.Status NOT IN (''9'',''CANC'') '
                         + ' AND ISNULL(ORDERS.Loadkey,'''') = '''' '
                         + @c_SQLWhere
                         + ' ORDER BY ORDERS.OrderKey '

        EXEC sp_executesql @c_SQLDYN02
                  ,  N'@c_Storerkey NVARCHAR(15)
                  ,  @c_Wavekey NVARCHAR(10)
                  ,  @c_Field01 NVARCHAR(60) 
                  ,  @c_Field02 NVARCHAR(60)
                  ,  @c_Field03 NVARCHAR(60)
                  ,  @c_Field04 NVARCHAR(60)
                  ,  @c_Field05 NVARCHAR(60)
                  ,  @c_Field06 NVARCHAR(60)
                  ,  @c_Field07 NVARCHAR(60)
                  ,  @c_Field08 NVARCHAR(60)
                  ,  @c_Field09 NVARCHAR(60)
                  ,  @c_Field10 NVARCHAR(60)'
                  ,  @c_Storerkey 
                  ,  @c_Wavekey 
                  ,  @c_Field01 
                  ,  @c_Field02 
                  ,  @c_Field03 
                  ,  @c_Field04 
                  ,  @c_Field05 
                  ,  @c_Field06 
                  ,  @c_Field07 
                  ,  @c_Field08 
                  ,  @c_Field09 
                  ,  @c_Field10

         OPEN cur_loadpland

         FETCH NEXT FROM cur_loadpland INTO @c_OrderKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
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
                    @cLoadKey          = @c_LoadKey 
                  , @cFacility         = @c_Facility 
                  , @cOrderKey         = @c_OrderKey 
                  , @cConsigneeKey     = @c_Consigneekey 
                  , @cPrioriry         = @c_Priority 
                  , @dOrderDate        = @d_OrderDate 
                  , @dDelivery_Date    = @d_Delivery_Date 
                  , @cOrderType        = @c_OrderType 
                  , @cDoor             = @c_Door 
                  , @cRoute            = @c_Route 
                  , @cDeliveryPlace    = @c_DeliveryPlace 
                  , @nStdGrossWgt      = @n_totweight 
                  , @nStdCube          = @n_totcube 
                  , @cExternOrderKey   = @c_ExternOrderKey 
                  , @cCustomerName     = @c_C_Company 
                  , @nTotOrderLines    = @n_TotOrdLine  
                  , @nNoOfCartons      = 0 
                  , @cOrderStatus      = @c_OrderStatus 
                  , @b_Success         = @b_Success OUTPUT 
                  , @n_err             = @n_err     OUTPUT 
                  , @c_errmsg          = @c_errmsg  OUTPUT

               SEt @n_err = @@ERROR

               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 63508
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into LOADPLANDETAIL Failed. (ispWAVLP04)'
                  GOTO RETURN_SP
               END
            END

            FETCH NEXT FROM cur_loadpland INTO @c_OrderKey
         END
         CLOSE cur_loadpland
         DEALLOCATE cur_loadpland

         SELECT TOP 1 @c_storerkey = ORDERS.Storerkey,
                      @c_facility = ORDERS.Facility
         FROM LOADPLANDETAIL WITH (NOLOCK)
         JOIN ORDERS         WITH (NOLOCK) ON LOADPLANDETAIL.Orderkey = ORDERS.Orderkey
         WHERE LOADPLANDETAIL.Loadkey = @c_Loadkey

         SET @c_authority = ''
         SET @b_success = 0
         EXECUTE nspGetRight
               @c_facility 
            ,  @c_StorerKey           -- Storer
            ,  NULL   -- Sku
            ,  'AutoUpdSupOrdflag'     -- ConfigKey
            ,  @b_success    output 
            ,  @c_authority  output 
            ,  @n_err        output  
            ,  @c_errmsg     output

         IF @b_success <> 1
         BEGIN
           SET @n_continue = 3
           SET @c_errmsg = 'ispWAVLP04:' + RTRIM(ISNULL(@c_errmsg,''))
         END
         ELSE IF @c_authority  = '1'
         BEGIN
            UPDATE LOADPLAN WITH (ROWLOCK)
            SET   SuperOrderFlag = 'Y'
                , TrafficCop = NULL
                , EditWho    = SUSER_NAME()
                , EditDate   = GETDATE()
            WHERE Loadkey = @c_LoadKey
         END

         FETCH NEXT FROM cur_LPGroup INTO @c_Storerkey, @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05,
                         @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10
      END
      CLOSE cur_LPGroup
      DEALLOCATE cur_LPGroup
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      -- Default Last Orders Flag to Y
      UPDATE ORDERS WITH (ROWLOCK)
         SET SectionKey = 'Y'
            ,TrafficCop = NULL
            ,EditWho    = SUSER_NAME()
            ,EditDate   = GETDATE()  
      FROM ORDERS
      JOIN WAVEDETAIL WD (NOLOCK) ON WD.OrderKey = ORDERS.OrderKey
      WHERE WD.WaveKey = @c_WaveKey
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @n_loadcount > 0
         SET @c_errmsg = RTRIM(CAST(@n_loadcount AS CHAR)) + ' Load Plan Generated'
      ELSE
         SET @c_errmsg = 'No Load Plan Generated'
   END
END

RETURN_SP:

WHILE @@TRANCOUNT < @n_StartTranCnt
BEGIN
   COMMIT TRAN
END

IF @n_continue=3 -- Error Occured - Process And Return
BEGIN
    SET @b_success = 0
    IF @@TRANCOUNT=1 AND @@TRANCOUNT>= @n_StartTranCnt
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
    EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispWAVLP04'
    RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
  
    RETURN
END
ELSE
BEGIN
    SET @b_success = 1
    WHILE @@TRANCOUNT>@n_StartTranCnt
    BEGIN
        COMMIT TRAN
    END
    RETURN
END

GO