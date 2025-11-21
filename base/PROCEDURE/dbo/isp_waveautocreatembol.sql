SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_WaveAutoCreateMBOL                             */  
/* Creation Date: 2012-05-02                                            */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: 257389 - US FNPC Auto MBOL Creation                         */
/*                                                                      */  
/*                                                                      */ 
/* Input Parameters:  @c_Wavekey  - (Wave #)                            */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage: call from Release to WCS ispWAVRL01                           */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */ 
/* Called By: ispWAVRL01                                                */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 10-Jun-2013  NJOW01   1.0  if no setup codelkup for the storer skip  */
/*                            auto create mbol                          */
/* 25-Sept-2013 lau     1.1    SOS# 290784 - correct check vendor id    */
/*                                         Add check customer id        */
/* 28-Jan-2019  TLTING_ext 1.2  enlarge externorderkey field length      */
/************************************************************************/  
CREATE  PROC  [dbo].[isp_WaveAutoCreateMBOL] 
   @c_WaveKey  NVARCHAR(10), 
   @b_Success  INT OUTPUT, 
   @n_err      INT OUTPUT, 
   @c_ErrMsg   NVARCHAR(250) OUTPUT 
AS
BEGIN
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_continue      int,  
           @n_StartTranCnt  int,        -- Holds the current transaction count
           @n_groupcnt      int,
           @n_wherecnt      int,
           @n_mbolcount     int
           
   DECLARE @c_Code            NVARCHAR(30)  --e.g. ORDERS.Orderkey
         , @c_Description     NVARCHAR(250)
         , @c_Long                NVARCHAR(250)  
         , @c_Storerkey       NVARCHAR(15)         
         , @c_TableName       NVARCHAR(30)
         , @c_ColumnName      NVARCHAR(30)
         , @c_ColumnType      NVARCHAR(10)
         , @c_SQLField        NVARCHAR(2000)
         , @c_SQLWhere        NVARCHAR(2000)
         , @c_SQLWhereGrp     NVARCHAR(2000)
         , @c_SQLGroup        NVARCHAR(2000)
         , @c_SQLDYN01        nVarChar(2000)
         , @c_SQLDYN02        nVarChar(2000)
         , @c_SQLDYN03        nVarChar(2000)
         , @c_Field01         NVARCHAR(60)
         , @c_Field02         NVARCHAR(60)
         , @c_Field03         NVARCHAR(60)
         , @c_Field04         NVARCHAR(60)
         , @c_Field05         NVARCHAR(60)
         , @c_Field06         NVARCHAR(60)
         , @c_Field07         NVARCHAR(60)
         , @c_Field08         NVARCHAR(60)
         , @c_Field09         NVARCHAR(60)
         , @c_Field10         NVARCHAR(60)
         , @c_ExternOrderKey  NVARCHAR(50)  --tlting_ext
         , @c_FoundMBOLKey    NVARCHAR(10)
         , @c_MBOLKey         NVARCHAR(10)
         , @c_Facility        NVARCHAR(5)
         , @c_Route           NVARCHAR(10)
         , @d_OrderDate       DateTime
         , @d_Delivery_Date   DateTime
         , @n_TotWeight       Float
         , @n_TotCube         Float
         , @c_Loadkey         NVARCHAR(10)
         , @c_Orderkey        NVARCHAR(10)
         
   DECLARE @n_NoOfVendor      Int
         , @c_PromptError     NVARCHAR(10)
         , @c_MBByVendorSetup NVARCHAR(30)
         , @c_MBOLByVendor    NVARCHAR(10)
         , @c_UserDefine05    NVARCHAR(20)        
                    
   SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue=1, @b_Success=1, @n_err=0, @c_ErrMsg='', @n_mbolcount = 0

   -------------------------- Wave Validation ------------------------------   
   IF NOT EXISTS( SELECT 1 FROM WAVEDETAIL WITH (NOLOCK)
                  WHERE WAVEKEY = @c_WaveKey )
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 63501
      SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": No Orders being populated INTO WaveDetail. (isp_WaveAutoCreateMBOL)"
      GOTO RETURN_SP
   END
   
   SELECT TOP 1 @c_Storerkey = O.Storerkey
   FROM WAVEDETAIL WD (NOLOCK)
   JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
   WHERE WD.Wavekey = @c_Wavekey
   
   IF EXISTS ( SELECT 1 FROM CODELKUP (NOLOCK) 
               WHERE Listname = 'WVAUTOMBOL'
               AND ISNULL(Storerkey,'') = '')
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 63502
      SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": ListName: WVAUTOMBOL Setup Must Have Storekey. (isp_WaveAutoCreateMBOL)"
      GOTO RETURN_SP
   END     
   
   --NJOW01
   IF NOT EXISTS (SELECT 1
                  FROM   CODELKUP WITH (NOLOCK)
                  WHERE  ListName = 'WVAUTOMBOL'
                  AND Storerkey = @c_Storerkey)
   BEGIN
      SELECT @n_continue = 4
      GOTO RETURN_SP
   END          
   -------------------------- Construct Wave Dynamic Grouping ------------------------------      
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN    
      DECLARE CUR_CODELKUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT TOP 10 Code, Description, Long
         FROM   CODELKUP WITH (NOLOCK)
         WHERE  ListName = 'WVAUTOMBOL'
         AND Storerkey = @c_Storerkey          
         ORDER BY Code

      OPEN CUR_CODELKUP
      FETCH NEXT FROM CUR_CODELKUP INTO @c_Code, @c_Description, @c_Long

      SELECT @c_SQLField = '', @c_SQLWhere = '', @c_SQLWhereGrp = '', @c_SQLGroup = '', @n_groupcnt = 0, @n_wherecnt = 0

      WHILE @@FETCH_STATUS <> -1
      BEGIN         
         SET @c_TableName = LEFT(@c_Code, CharIndex('.', @c_Code) - 1)
         SET @c_ColumnName = SUBSTRING(@c_Code,
               CharIndex('.', @c_Code) + 1, LEN(@c_Code) - CharIndex('.', @c_Code))

         IF ISNULL(RTRIM(@c_TableName), '') NOT IN('ORDERS','SKU')
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63504
            SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Grouping Only Allow Refer To Wave/Orders/Sku Table's Fields. Invalid Table: "+RTRIM(@c_Code)+" (isp_WaveAutoCreateMBOL)"
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
            SELECT @n_err = 63505
            SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Invalid Column Name: " + RTRIM(@c_Code)+ ". (isp_WaveAutoCreateMBOL)"
            GOTO RETURN_SP
         END

         IF @c_ColumnType IN ('Float', 'money', 'Int', 'decimal', 'numeric', 'tinyInt', 'real', 'bigInt','text')
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63506
            SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Numeric/Text Column Type Is Not Allowed For MBOL Grouping: " + RTRIM(@c_Code)+ ". (isp_WaveAutoCreateMBOL)"
            GOTO RETURN_SP
         END

         IF ISNULL(@c_Long,'') = ''
            SET @n_groupcnt = @n_groupcnt + 1
         ELSE
            SET @n_wherecnt = @n_wherecnt + 1               
            
         IF @c_ColumnType IN ('Char', 'nVarChar', 'VarChar', 'nChar')
         BEGIN
              IF ISNULL(@c_Long,'') = ''
              BEGIN
               SELECT @c_SQLField = @c_SQLField + ',' + RTRIM(@c_Code)
               SELECT @c_SQLWhereGrp = @c_SQLWhereGrp + ' AND ' + RTRIM(@c_Code) + '=' +
                                       CASE WHEN @n_Groupcnt = 1 THEN '@c_Field01'
                                       WHEN @n_Groupcnt = 2 THEN '@c_Field02'
                                       WHEN @n_Groupcnt = 3 THEN '@c_Field03'
                                       WHEN @n_Groupcnt = 4 THEN '@c_Field04'
                                       WHEN @n_Groupcnt = 5 THEN '@c_Field05'
                                       WHEN @n_Groupcnt = 6 THEN '@c_Field06'
                                       WHEN @n_Groupcnt = 7 THEN '@c_Field07'
                                       WHEN @n_Groupcnt = 8 THEN '@c_Field08'
                                       WHEN @n_Groupcnt = 9 THEN '@c_Field09'
                                       WHEN @n_Groupcnt = 10 THEN '@c_Field10' END
            END
            ELSE
            BEGIN
                SELECT @c_SQLWhere = @c_SQLWhere + ' AND ' + RTRIM(@c_Code) + '=''' + RTRIM(@c_Long) + ''' ' 
            END
         END

         IF @c_ColumnType IN ('datetime')
         BEGIN
              IF ISNULL(@c_Long,'') = ''
              BEGIN
               SELECT @c_SQLField = @c_SQLField + ', CONVERT(VarChar(10),' + RTRIM(@c_Code) + ',112)'
               SELECT @c_SQLWhereGrp = @c_SQLWhereGrp + ' AND CONVERT(VarChar(10),' + RTRIM(@c_Code) + ',112)=' +
                                       CASE WHEN @n_Groupcnt = 1 THEN '@c_Field01'
                                       WHEN @n_Groupcnt = 2 THEN '@c_Field02'
                                       WHEN @n_Groupcnt = 3 THEN '@c_Field03'
                                       WHEN @n_Groupcnt = 4 THEN '@c_Field04'
                                       WHEN @n_Groupcnt = 5 THEN '@c_Field05'
                                       WHEN @n_Groupcnt = 6 THEN '@c_Field06'
                                       WHEN @n_Groupcnt = 7 THEN '@c_Field07'
                                       WHEN @n_Groupcnt = 8 THEN '@c_Field08'
                                       WHEN @n_Groupcnt = 9 THEN '@c_Field09'
                                       WHEN @n_Groupcnt = 10 THEN '@c_Field10' END
            END
            ELSE
            BEGIN
               SELECT @c_SQLWhere = @c_SQLWhere + ' AND CONVERT(VarChar(10),' + RTRIM(@c_Code) + ',112)=''' + RTRIM(@c_Long) + ''' '  --YYYYMMDD
            END
         END

         FETCH NEXT FROM CUR_CODELKUP INTO @c_Code, @c_Description, @c_Long
      END
      CLOSE CUR_CODELKUP
      DEALLOCATE CUR_CODELKUP

      SELECT @c_SQLGroup = @c_SQLField
      WHILE @n_Groupcnt < 10
      BEGIN
         SET @n_Groupcnt = @n_Groupcnt + 1
         SELECT @c_SQLField = @c_SQLField + ','''''

         SELECT @c_SQLWhereGrp = @c_SQLWhereGrp + ' AND ''''=' +
                                 CASE WHEN @n_Groupcnt = 1 THEN 'ISNULL(@c_Field01,'''')'
                                 WHEN @n_Groupcnt = 2 THEN 'ISNULL(@c_Field02,'''')'
                                 WHEN @n_Groupcnt = 3 THEN 'ISNULL(@c_Field03,'''')'
                                 WHEN @n_Groupcnt = 4 THEN 'ISNULL(@c_Field04,'''')'
                                 WHEN @n_Groupcnt = 5 THEN 'ISNULL(@c_Field05,'''')'
                                 WHEN @n_Groupcnt = 6 THEN 'ISNULL(@c_Field06,'''')'
                                 WHEN @n_Groupcnt = 7 THEN 'ISNULL(@c_Field07,'''')'
                                 WHEN @n_Groupcnt = 8 THEN 'ISNULL(@c_Field08,'''')'
                                 WHEN @n_Groupcnt = 9 THEN 'ISNULL(@c_Field09,'''')'
                                 WHEN @n_Groupcnt = 10 THEN 'ISNULL(@c_Field10,'''')' END
      END
   END
   
   BEGIN TRAN

   -------------------------- CREATE MBOL ------------------------------
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_SQLDYN01 = 'DECLARE cur_MBGroup CURSOR FAST_FORWARD READ_ONLY FOR '
                         + ' SELECT ORDERS.Storerkey ' + @c_SQLField
                         + ' FROM ORDERS WITH (NOLOCK) '
                         + ' JOIN ORDERDETAIL OD WITH (NOLOCK) ON (ORDERS.OrderKey = OD.OrderKey) '
                         + ' JOIN SKU WITH (NOLOCK) ON (OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku) '
                         + ' JOIN WAVEDETAIL WD WITH (NOLOCK) ON (ORDERS.OrderKey = WD.OrderKey) '
                         +'  WHERE WD.WaveKey = ''' +  RTRIM(@c_WaveKey) +''''
                         + ' AND ISNULL(ORDERS.Mbolkey,'''') = '''' '
                         + ' AND ORDERS.Status NOT IN (''9'',''CANC'') '
                         + @c_SQLWhere 
                         + ' GROUP BY ORDERS.Storerkey ' + @c_SQLGroup
                         + ' ORDER BY ORDERS.Storerkey ' + @c_SQLGroup

      EXEC (@c_SQLDYN01)

      OPEN cur_MBGroup
      FETCH NEXT FROM cur_MBGroup INTO @c_Storerkey, @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05,
                                       @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SELECT @c_SQLDYN02 = ' SELECT @c_FoundMBOLKey = MAX(ORDERS.MBOLKey) '
                            + ' FROM ORDERS WITH (NOLOCK) '
                            + ' JOIN ORDERDETAIL OD WITH (NOLOCK) ON (ORDERS.OrderKey = OD.OrderKey) '
                            + ' JOIN SKU WITH (NOLOCK) ON (OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku) '
                            + ' JOIN WAVEDETAIL WD WITH (NOLOCK) ON (ORDERS.OrderKey = WD.OrderKey) '
                            + ' WHERE ORDERS.StorerKey = @c_StorerKey '
                            + ' AND WD.WaveKey = @c_WaveKey '
                            + ' AND ORDERS.Status NOT IN (''9'',''CANC'') '
                            + ' AND ISNULL(ORDERS.MBOLKey,'''') <> '''' '
                            + @c_SQLWhere
                            + @c_SQLWhereGrp

         EXEC sp_executesql @c_SQLDYN02,
                           N'@c_Storerkey NVARCHAR(15), @c_Wavekey NVARCHAR(10), @c_Field01 NVARCHAR(60), @c_Field02 NVARCHAR(60),@c_Field03 NVARCHAR(60),@c_Field04 NVARCHAR(60),
                           @c_Field05 NVARCHAR(60), @c_Field06 NVARCHAR(60), @c_Field07 NVARCHAR(60), @c_Field08 NVARCHAR(60), @c_Field09 NVARCHAR(60), @c_Field10 NVARCHAR(60), @c_FoundMBOLKey NVARCHAR(10) OUTPUT',
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
                           @c_FoundMBOLKey OUTPUT

         IF ISNULL(@c_FoundMBOLKey,'') <> ''
         BEGIN
            SET @c_MBOLKey = @c_FoundMBOLKey
         END
         ELSE
         BEGIN
            SELECT @b_success = 0
            EXECUTE nspg_GetKey
                   'MBOL',
                   10,
                   @c_MBOLKey OUTPUT,
                   @b_success OUTPUT,
                   @n_err     OUTPUT,
                   @c_errmsg  OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               GOTO RETURN_SP
            END

            SELECT @c_Facility = MAX(Orders.Facility)
            FROM Orders WITH (NOLOCK)
            JOIN Wavedetail WITH (NOLOCK) ON (Orders.Orderkey = Wavedetail.Orderkey)
            WHERE Wavedetail.Wavekey = @c_WaveKey
            AND Orders.Storerkey = @c_StorerKey
            AND Orders.Status NOT IN ('9','CANC')
            AND ISNULL(Orders.MBOLKey,'') = ''

            -- Create MBOL
            INSERT INTO MBOL (MBOLKey, Facility, PlaceOfdeliveryQualifier, TransMethod, Userdefine09, Userdefine02, Userdefine04) 
            VALUES (@c_MBOLKey, @c_Facility, 'D','O', @c_Wavekey, 'Y', 'Y')

            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 63507
               SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Insert INTO MBOL Failed. (isp_WaveAutoCreateMBOL)"
               GOTO RETURN_SP
            END
         END

         SELECT @n_mbolcount = @n_mbolcount + 1

         -- Create mbol detail
         SELECT @c_SQLDYN03 = 'DECLARE cur_mboldet CURSOR FAST_FORWARD READ_ONLY FOR '
                            + ' SELECT ORDERS.OrderKey '
                            + ' FROM ORDERS WITH (NOLOCK) '
                            + ' JOIN ORDERDETAIL OD WITH (NOLOCK) ON (ORDERS.OrderKey = OD.OrderKey) '
                            + ' JOIN SKU WITH (NOLOCK) ON (OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku) '
                            + ' JOIN WAVEDETAIL WD WITH (NOLOCK) ON (ORDERS.OrderKey = WD.OrderKey) '
                            + ' WHERE ORDERS.StorerKey = @c_StorerKey ' +
                            + ' AND WD.WaveKey = @c_WaveKey '
                            + ' AND ORDERS.Status NOT IN (''9'',''CANC'') '
                            + ' AND ISNULL(ORDERS.MBOLKey,'''') = '''' '
                            + @c_SQLWhere
                            + @c_SQLWhereGrp                            
                            + ' ORDER BY ORDERS.OrderKey '

         EXEC sp_executesql @c_SQLDYN03,
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

         OPEN cur_mboldet
         FETCH NEXT FROM cur_mboldet INTO @c_OrderKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF (SELECT COUNT(1) FROM MbolDetail WITH (NOLOCK) WHERE OrderKey = @c_OrderKey) = 0
            BEGIN
               SELECT @d_OrderDate = O.OrderDate,
                      @d_Delivery_Date = O.DeliveryDate,
                      @c_Route = O.Route,
                      @n_totweight = SUM((OD.Qtyallocated + OD.QtyPicked + OD.ShippedQty) * SKU.StdGrossWgt),
                      @n_totcube = SUM((OD.Qtyallocated + OD.QtyPicked + OD.ShippedQty) * SKU.StdCube),
                      @c_ExternOrderkey = O.ExternOrderkey,
                      @c_Loadkey = ISNULL(O.Loadkey,'')
               FROM Orders O WITH (NOLOCK)
               JOIN Orderdetail OD WITH (NOLOCK) ON (O.Orderkey = OD.Orderkey)
               JOIN SKU WITH (NOLOCK) ON (OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku)
               WHERE O.OrderKey = @c_OrderKey
               GROUP BY O.OrderDate,
                        O.DeliveryDate,
                        O.Route,
                        O.ExternOrderkey,
                  ISNULL(O.Loadkey,'')

               EXEC isp_InsertMBOLDetail
                     @cMBOLKey        = @c_MBOLKey,
                     @cFacility       = @c_Facility,
                     @cOrderKey       = @c_OrderKey,
                     @cLoadKey        = @c_Loadkey,
                     @nStdGrossWgt    = @n_totweight,
                     @nStdCube        = @n_totcube,
                     @cExternOrderKey = @c_ExternOrderkey,
                     @dOrderDate      = @d_OrderDate,
                     @dDelivery_Date  = @d_Delivery_Date,
                     @cRoute          = @c_Route,
                     @b_Success       = @b_Success OUTPUT,
                     @n_err           = @n_err     OUTPUT,
                     @c_errmsg        = @c_errmsg  OUTPUT

               SELECT @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 63508
                  SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Insert INTO MBOLDETAIL Failed. (isp_WaveAutoCreateMBOL)"
                  GOTO RETURN_SP
               END
            END

            FETCH NEXT FROM cur_mboldet INTO @c_OrderKey
         END
         CLOSE cur_mboldet
         DEALLOCATE cur_mboldet

         -- SOS# 253552 (Start)
         SELECT TOP 1 @c_Storerkey = Storerkey, @c_Facility = Facility
         FROM ORDERS WITH (NOLOCK)
         WHERE Userdefine09 = @c_Wavekey

         EXECUTE nspGetRight
               @c_Facility,      -- facility
               @c_StorerKey,     -- Storerkey
               NULL,             -- Sku
               'MBOLBYVENDOR',   -- Configkey
               @b_Success        OUTPUT,
               @c_MBOLByVendor   OUTPUT,
               @n_err            OUTPUT,
               @c_ErrMsg         OUTPUT

         IF ISNULL(RTRIM(@c_MBOLByVendor),'') = '1'
         BEGIN
            SELECT @n_NoOfVendor      = COUNT(DISTINCT ISNULL(RTRIM(ORDERS.UserDefine05),'')),
                   @c_PromptError     = ISNULL(MAX(ISNULL(RTRIM(CODELKUP.Short),'')),''),
                   @c_MBByVendorSetup = ISNULL(MIN(ISNULL(RTRIM(Codelkup.Code),'')),'')
                 , @c_UserDefine05    = ISNULL(MIN(RTRIM(ORDERS.UserDefine05)),'') -- SOS# 253552
            FROM MBOLDETAIL MD WITH (NOLOCK)
            JOIN ORDERS WITH (NOLOCK) ON (MD.Orderkey = ORDERS.Orderkey)
            -- LEFT JOIN CODELKUP WITH (NOLOCK) ON (CODELKUP.ListName = 'MBBYVENDOR') AND(ORDERS.C_IsoCntryCode = CODELKUP.Code) --lau
         LEFT JOIN CODELKUP WITH (NOLOCK) ON (CODELKUP.ListName = 'MBBYVENDOR') AND(LEFT(RIGHT(ORDERS.C_IsoCntryCode,6),4) = CODELKUP.Code)
            WHERE MD.Mbolkey = @c_MBOLKey

            --IF @n_NoOfVendor > 1 AND (@c_PromptError = 'Y' OR ISNULL(@c_MBByVendorSetup,'') = '') -- lau
         IF @n_NoOfVendor > 1 AND (@c_PromptError = 'Y')
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 63502
               SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Cannot Mix Vendor (isp_WaveAutoCreateMBOL)"
               GOTO RETURN_SP
            END
         
         /****************************/
         /* check Customer ID -Start */
          /****************************/
            SELECT @n_NoOfVendor      = COUNT(DISTINCT ISNULL(RTRIM(ORDERS.C_IsoCntryCode),'')),
                   @c_PromptError     = ISNULL(MAX(ISNULL(RTRIM(CODELKUP.Long),'')),''),
                   @c_MBByVendorSetup = ISNULL(MIN(ISNULL(RTRIM(Codelkup.Code),'')),'')
            FROM MBOLDETAIL MD WITH (NOLOCK)
            JOIN ORDERS WITH (NOLOCK) ON (MD.Orderkey = ORDERS.Orderkey)
            LEFT JOIN CODELKUP WITH (NOLOCK) ON (CODELKUP.ListName = 'MBBYVENDOR') AND(LEFT(RIGHT(ORDERS.C_IsoCntryCode,6),4) = CODELKUP.Code)
            WHERE MD.Mbolkey = @c_MBOLKey

            IF @n_NoOfVendor > 1 AND (@c_PromptError = 'Y' OR ISNULL(@c_MBByVendorSetup,'') = '')
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 63502
               SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Cannot Mix Customer ID (isp_WaveAutoCreateMBOL)"
               GOTO RETURN_SP
            END
                  
         /****************************/
         /* check Customer ID -End */
          /****************************/        
         END
         -- SOS# 253552 (End)

         FETCH NEXT FROM cur_MBGroup INTO @c_Storerkey, @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05,
                                          @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10
      END
      CLOSE cur_MBGroup
      DEALLOCATE cur_MBGroup
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @n_mbolcount > 0
         SELECT @c_errmsg = RTRIM(CAST(@n_mbolcount AS Char)) + ' MBOL Generated. Refer to MBOL Userdefine09 for Wave# ' + RTRIM(@c_Wavekey)
      ELSE
         SELECT @c_errmsg = 'No MBOL Generated'
   END 
END -- Procedure

RETURN_SP:

IF @n_continue=3  -- Error Occured - Process And Return
BEGIN
   IF CURSOR_STATUS('GLOBAL','cur_MBGroup') IN (0,1) -- SOS# 253552
   BEGIN
      CLOSE cur_MBGroup
      DEALLOCATE cur_MBGroup
   END

   SELECT @b_success = 0
   IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt
   BEGIN
      ROLLBACK TRAN
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         COMMIT TRAN
      END
   END
   execute nsp_logerror @n_err, @c_errmsg, 'isp_WaveAutoCreateMBOL'
   --RAISERROR @n_err @c_errmsg
   RETURN
END
ELSE
BEGIN
   SELECT @b_success = 1
   WHILE @@TRANCOUNT > @n_StartTranCnt
   BEGIN
      COMMIT TRAN
   END
   RETURN
END

GO