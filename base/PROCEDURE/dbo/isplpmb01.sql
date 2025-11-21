SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/**************************************************************************/
/* Store Procedure: ispLPMB01                                             */
/* Creation Date:  05-Mar-2011                                            */
/* Copyright: IDS                                                         */
/* Written by:  NJOW                                                      */
/*                                                                        */
/* Purpose:  Load Plan Generate Mbol (SOS#238090)                         */
/*                                                                        */
/* Input Parameters:  @c_Loadkey  - (LoadKey)                             */
/*                                                                        */
/* Output Parameters:  None                                               */
/*                                                                        */
/* Return Status:  None                                                   */
/*                                                                        */
/* Usage:                                                                 */
/*                                                                        */
/* Local Variables:                                                       */
/*                                                                        */
/* Called By:  RMC Generate MBOL From Load Plan                           */
/*                                                                        */
/* PVCS Version: 1.2                                                      */
/*                                                                        */
/* Version: 5.4                                                           */
/*                                                                        */
/* Data Modifications:                                                    */
/*                                                                        */
/* Updates:                                                               */
/* Date        Author     Ver  Purposes                                   */
/* 17-Apr-2012 NJOW01     1.0  238090-Default mbol.userdefine02 & 04 to Y */
/* 22-Jun-2012 NJOW02     1.1  243856-Add vendor validation               */
/* 16-Aug-2012 Leong      1.2  SOS# 253552 - Check MBOLDetail when config */
/*                                           key MBOLBYVENDOR turn on     */
/* 25-Sep-2013 lau	  	  1.3	 SOS# 290784 - correct check vendor id      */
/*                                           Add check customer id        */
/* 27-Jun-2018 NJOW03     1.4  Fix - include NCHAR                        */
/* 28-Jan-2019 TLTING_ext 1.5  enlarge externorderkey field length        */
/* 28-Jun-2021 NJOW04     1.6  Fix datatime to datetime                   */
/**************************************************************************/

CREATE PROC [dbo].[ispLPMB01]
   @c_LoadKey NVARCHAR(10),
   @b_Success Int          OUTPUT,
   @n_err     Int          OUTPUT,
   @c_errmsg  NVARCHAR(250) OUTPUT
AS
BEGIN

   SET NOCOUNT ON       -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_OrderKey        NVARCHAR(10)
         , @c_Facility        NVARCHAR(5)
         , @c_ExternOrderKey  NVARCHAR(50)  --tlting_ext
         , @c_StorerKey       NVARCHAR(15)
         , @c_Route           NVARCHAR(10)
         , @c_MBOLKey         NVARCHAR(10)
         , @n_continue        Int
         , @n_StartTranCnt    Int
         , @d_OrderDate       DateTime
         , @d_Delivery_Date   DateTime
         , @n_mbolcount       Int
         , @n_TotWeight       Float
         , @n_TotCube         Float

   DECLARE @c_ListName        NVARCHAR(10)
         , @c_Code            NVARCHAR(30) -- e.g. ORDERS01
         , @c_Description     NVARCHAR(250)
         , @c_TableColumnName NVARCHAR(250)  -- e.g. ORDERS.Orderkey
         , @c_TableName       NVARCHAR(30)
         , @c_ColumnName      NVARCHAR(30)
         , @c_ColumnType      NVARCHAR(10)
         , @c_SQLField        NVARCHAR(2000)
         , @c_SQLWhere        NVARCHAR(2000)
         , @c_SQLGroup        NVARCHAR(2000)
         , @c_SQLDYN01        NVARCHAR(2000)
         , @c_SQLDYN02        NVARCHAR(2000)
         , @c_SQLDYN03        NVARCHAR(2000)
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
         , @n_cnt             Int
         , @c_FoundMBOLKey    NVARCHAR(10)

   --NJOW02
   DECLARE @n_NoOfVendor      Int
         , @c_PromptError     NVARCHAR(10)
         , @c_MBByVendorSetup NVARCHAR(30)
         , @c_MBOLByVendor    NVARCHAR(10)
         , @c_UserDefine05    NVARCHAR(20) -- SOS# 253552

   SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue = 1, @n_mbolcount = 0

   -------------------------- Load Plan Validation ------------------------------
   IF NOT EXISTS( SELECT 1 FROM LoadPlanDetail WITH (NOLOCK)
                  WHERE LoadKey = @c_LoadKey )
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 63501
      SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": No Orders being populated INTO LoadDetail. (ispLPMB01)"
      GOTO RETURN_SP
   END

   --NJOW02 Start
   --SELECT TOP 1 @c_Storerkey = Storerkey, @c_Facility = Facility
   --FROM ORDERS WITH (NOLOCK)
   --WHERE Loadkey = @c_Loadkey

   --EXECUTE nspGetRight
   --      @c_Facility,      -- facility
   --      @c_StorerKey,     -- Storerkey
   --      NULL,             -- Sku
   --      'MBOLBYVENDOR',   -- Configkey
   --      @b_Success        OUTPUT,
   --      @c_MBOLByVendor   OUTPUT,
   --      @n_err            OUTPUT,
   --      @c_ErrMsg         OUTPUT

   --IF ISNULL(RTRIM(@c_MBOLByVendor),'') = '1'
   --BEGIN
   --   SELECT @n_NoOfVendor      = COUNT(DISTINCT ISNULL(RTRIM(ORDERS.UserDefine05),'')),
   --          @c_PromptError     = ISNULL(MAX(ISNULL(RTRIM(CODELKUP.Short),'')),''),
   --          @c_MBByVendorSetup = ISNULL(MIN(ISNULL(RTRIM(Codelkup.Code),'')),'')
   --        , @c_UserDefine05    = ISNULL(MIN(RTRIM(ORDERS.UserDefine05)),'') -- SOS# 253552
   --   FROM LOADPLANDETAIL LD WITH (NOLOCK)
   --   JOIN ORDERS WITH (NOLOCK) ON (LD.Orderkey = ORDERS.Orderkey)
   --   LEFT JOIN CODELKUP WITH (NOLOCK) ON (CODELKUP.ListName = 'MBBYVENDOR') AND(ORDERS.C_IsoCntryCode = CODELKUP.Code)
   --   WHERE LD.Loadkey = @c_Loadkey

   --   IF @n_NoOfVendor > 1 AND (@c_PromptError = 'Y' OR ISNULL(@c_MBByVendorSetup,'') = '')
   --   BEGIN
   --      SELECT @n_continue = 3
   --      SELECT @n_err = 63502
   --      SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Cannot Mix Vendor (ispLPMB01)"
   --      GOTO RETURN_SP
   --   END
   --END
   --NJOW02 End

   -------------------------- Construct Load Plan Dynamic Grouping ------------------------------
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_listname = CODELIST.Listname
      FROM LOADPLAN WITH (NOLOCK)
      JOIN CODELIST WITH (NOLOCK) ON LOADPLAN.MBOLGroupMethod = CODELIST.Listname AND CODELIST.ListGroup = 'LPMBOLGROUP'
      WHERE LOADPLAN.Loadkey = @c_LoadKey

      IF ISNULL(@c_ListName,'') = ''
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63503
         SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Empty/Invalid MBOL Group Is Not Allowed. (LIST GROUP: LPMBOLGROUP) (ispLPMB01)"
         GOTO RETURN_SP
      END

      DECLARE CUR_CODELKUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT TOP 10 Code, Description, Long
         FROM   CODELKUP WITH (NOLOCK)
         WHERE  ListName = @c_ListName
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
            SELECT @n_err = 63504
            SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Grouping Only Allow Refer To Orders Table's Fields. Invalid Table: "+RTRIM(@c_TableColumnName)+" (ispLPMB01)"
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
            SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Invalid Column Name: " + RTRIM(@c_TableColumnName)+ ". (ispLPMB01)"
            GOTO RETURN_SP
         END

         IF @c_ColumnType IN ('Float', 'money', 'Int', 'decimal', 'numeric', 'tinyInt', 'real', 'bigInt','text')
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63506
            SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Numeric/Text Column Type Is Not Allowed For MBOL Grouping: " + RTRIM(@c_TableColumnName)+ ". (ispLPMB01)"
            GOTO RETURN_SP
         END

         IF @c_ColumnType IN ('CHAR', 'NVARCHAR', 'VARCHAR','NCHAR') --NJOW03
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

         IF @c_ColumnType IN ('datetime') --NJOW04
         BEGIN
            SELECT @c_SQLField = @c_SQLField + ', CONVERT(VarChar(10),' + RTRIM(@c_TableColumnName) + ',112)'
            SELECT @c_SQLWhere = @c_SQLWhere + ' AND CONVERT(VarChar(10),' + RTRIM(@c_TableColumnName) + ',112)=' +
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

   BEGIN TRAN
   -------------------------- CREATE MBOL ------------------------------
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_SQLDYN01 = 'DECLARE cur_MBGroup CURSOR FAST_FORWARD READ_ONLY FOR '
                         + ' SELECT ORDERS.Storerkey ' + @c_SQLField
                         + ' FROM ORDERS WITH (NOLOCK) '
                         + ' JOIN LoadPlanDetail LD WITH (NOLOCK) ON (ORDERS.OrderKey = LD.OrderKey) '
                         +'  WHERE LD.LoadKey = ''' +  RTRIM(@c_LoadKey) +''''
                         + ' AND ISNULL(ORDERS.MBOLKey,'''') = '''' '
                         + ' AND ORDERS.Status NOT IN (''9'',''CANC'') '
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
                            + ' JOIN LoadPlanDetail LD WITH (NOLOCK) ON (ORDERS.OrderKey = LD.OrderKey) '
                            + ' WHERE  ORDERS.StorerKey = @c_StorerKey '
                            + ' AND LD.LoadKey = @c_LoadKey '
                            + ' AND ORDERS.Status NOT IN (''9'',''CANC'') '
                            + ' AND ISNULL(ORDERS.MBOLKey,'''') <> '''' '
                            + @c_SQLWhere

         EXEC sp_executesql @c_SQLDYN02,
                           N'@c_Storerkey NVARCHAR(15), @c_Loadkey NVARCHAR(10), @c_Field01 NVARCHAR(60), @c_Field02 NVARCHAR(60),@c_Field03 NVARCHAR(60),@c_Field04 NVARCHAR(60),
                           @c_Field05 NVARCHAR(60), @c_Field06 NVARCHAR(60), @c_Field07 NVARCHAR(60), @c_Field08 NVARCHAR(60), @c_Field09 NVARCHAR(60), @c_Field10 NVARCHAR(60), @c_FoundMBOLKey NVARCHAR(10) OUTPUT',
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

            SELECT @c_Facility = MAX(Facility)
            FROM Orders WITH (NOLOCK)
            WHERE Loadkey = @c_LoadKey
            AND Storerkey = @c_StorerKey
            AND Status NOT IN ('9','CANC')
            AND ISNULL(MBOLKey,'') = ''

            -- Create MBOL
            INSERT INTO MBOL (MBOLKey, Facility, PlaceOfdeliveryQualifier, TransMethod, Userdefine09, Userdefine02, Userdefine04) --NJOW01
            VALUES (@c_MBOLKey, @c_Facility, 'D','O', @c_Loadkey, 'Y', 'Y')

            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 63507
               SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Insert INTO MBOL Failed. (ispLPMB01)"
               GOTO RETURN_SP
            END
         END

         SELECT @n_mbolcount = @n_mbolcount + 1

         -- Create mbol detail
         SELECT @c_SQLDYN03 = 'DECLARE cur_mboldet CURSOR FAST_FORWARD READ_ONLY FOR '
                            + ' SELECT ORDERS.OrderKey '
                            + ' FROM ORDERS WITH (NOLOCK) '
                            + ' JOIN LoadPlanDetail LD WITH (NOLOCK) ON (ORDERS.OrderKey = LD.OrderKey) '
                            + ' WHERE  ORDERS.StorerKey = @c_StorerKey ' +
                            + ' AND LD.LoadKey = @c_LoadKey '
                            + ' AND ORDERS.Status NOT IN (''9'',''CANC'') '
                            + ' AND ISNULL(ORDERS.MBOLKey,'''') = '''' '
                            + @c_SQLWhere
                            + ' ORDER BY ORDERS.OrderKey '

         EXEC sp_executesql @c_SQLDYN03,
                           N'@c_Storerkey NVARCHAR(15), @c_Loadkey NVARCHAR(10), @c_Field01 NVARCHAR(60), @c_Field02 NVARCHAR(60),@c_Field03 NVARCHAR(60),@c_Field04 NVARCHAR(60),
                           @c_Field05 NVARCHAR(60), @c_Field06 NVARCHAR(60), @c_Field07 NVARCHAR(60), @c_Field08 NVARCHAR(60), @c_Field09 NVARCHAR(60), @c_Field10 NVARCHAR(60)',
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
                      @c_ExternOrderkey = O.ExternOrderkey
               FROM Orders O WITH (NOLOCK)
               JOIN Orderdetail OD WITH (NOLOCK) ON (O.Orderkey = OD.Orderkey)
               JOIN SKU WITH (NOLOCK) ON (OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku)
               WHERE O.OrderKey = @c_OrderKey
               GROUP BY O.OrderDate,
                        O.DeliveryDate,
                        O.Route,
                        O.ExternOrderkey

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
                  SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Insert INTO MBOLDETAIL Failed. (ispLPMB01)"
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
         WHERE Loadkey = @c_Loadkey

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
            --LEFT JOIN CODELKUP WITH (NOLOCK) ON (CODELKUP.ListName = 'MBBYVENDOR') AND(ORDERS.C_IsoCntryCode = CODELKUP.Code)
			LEFT JOIN CODELKUP WITH (NOLOCK) ON (CODELKUP.ListName = 'MBBYVENDOR') AND (LEFT(RIGHT(ORDERS.C_IsoCntryCode,6),4) = CODELKUP.Code)   -- lau
            WHERE MD.Mbolkey = @c_MBOLKey

            --IF @n_NoOfVendor > 1 AND (@c_PromptError = 'Y' OR ISNULL(@c_MBByVendorSetup,'') = '')  -- lau
            IF @n_NoOfVendor > 1 AND (@c_PromptError = 'Y')			
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 63502
               SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Cannot Mix Vendor (ispLPMB01)"
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
               SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Cannot Mix Customer ID (ispLPMB01)"
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
         SELECT @c_errmsg = RTRIM(CAST(@n_mbolcount AS Char)) + ' MBOL Generated. Refer to MBOL Userdefine09 for Load#'
      ELSE
         SELECT @c_errmsg = 'No MBOL Generated'
   END
END

RETURN_SP:

IF @n_continue = 3  -- Error Occured - Process And Return
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
   EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispLPMB01'
   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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