SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: ispWAVMB01                                          */
/* Creation Date:  31-Jul-2018                                          */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  WMS-5760 CN Levi Wave Generate MBOL                        */
/*                                                                      */
/* Input Parameters:  Wavekey                                           */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:  RMC Generate MBOL From Wave                              */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author     Ver  Purposes                                 */
/* 28-Jan-2019 TLTING_ext 1.0  enlarge externorderkey field length     	*/
/* 14-Mar-2019 NJOW01     1.1  Fix join bug                             */
/* 28-Jun-2021 NJOW02     1.2  Fix datatime to datetime                 */
/* 07-Mar-2023 WLChooi    1.3  WMS-21905 - Add SkipUpdateMBOLUserdefine */
/*                             config (WL01)                            */
/* 07-Mar-2023 WLChooi    1.3  DevOps Combine Script                    */
/* 14-Apr-2023 NJOW03     1.4  WMS-22311 allow add custom filtering     */
/************************************************************************/

CREATE   PROC [dbo].[ispWAVMB01]
   @c_WaveKey NVARCHAR(10),
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
         , @c_Loadkey         NVARCHAR(10)
         , @c_Facility        NVARCHAR(5)
         , @c_ExternOrderKey  NVARCHAR(50)   --tlting_ext
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
         , @c_Configkey       NVARCHAR(30) = 'WAVEGENMBOL_SP'   --WL01
         , @c_Authority       NVARCHAR(30)   --WL01
         , @c_Userdefine02    NVARCHAR(20)   --WL01
         , @c_Userdefine04    NVARCHAR(20)   --WL01
         , @c_Userdefine09    NVARCHAR(10)   --WL01
         , @c_Option5         NVARCHAR(4000) --WL01
         , @c_SkipUpdateMBOLUserdefine NVARCHAR(10) = 'N'   --WL01
         , @c_Condition       NVARCHAR(MAX)='' --NJOW03

   SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue = 1, @n_mbolcount = 0

   -------------------------- Wave Validation ------------------------------
   IF NOT EXISTS( SELECT 1 FROM WaveDetail WITH (NOLOCK)
                  WHERE WaveKey = @c_WaveKey )
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 63501
      SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": No Orders being populated INTO WaveDetail. (ispWAVMB01)"
      GOTO RETURN_SP
   END

   --WL01 S
   SET @c_Userdefine02 = 'Y'
   SET @c_Userdefine04 = 'Y'
   SET @c_Userdefine09 = @c_WaveKey

   SELECT @c_StorerKey = MIN(OH.Storerkey)
        , @c_Facility  = MIN(OH.Facility)
   FROM WAVEDETAIL WD (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
   WHERE WD.WaveKey = @c_WaveKey

   EXECUTE nspGetRight                                
      @c_Facility  = @c_Facility,                     
      @c_StorerKey = @c_StorerKey,                    
      @c_sku       = '',
      @c_ConfigKey = @c_Configkey,
      @b_Success   = @b_Success   OUTPUT,             
      @c_authority = @c_Authority OUTPUT,             
      @n_err       = @n_err       OUTPUT,             
      @c_errmsg    = @c_errmsg    OUTPUT,                           
      @c_Option5   = @c_Option5   OUTPUT
     
   IF ISNULL(@c_authority,'') = 'ispWAVMB01'
   BEGIN
      SELECT @c_SkipUpdateMBOLUserdefine = dbo.fnc_GetParamValueFromString('@c_SkipUpdateMBOLUserdefine', @c_Option5, 'N')  

      IF @c_SkipUpdateMBOLUserdefine = 'Y'
      BEGIN
         SET @c_Userdefine02 = ''
         SET @c_Userdefine04 = ''
         SET @c_Userdefine09 = ''
      END
   END
   --WL01 E

   -------------------------- Construct Wave Dynamic Grouping ------------------------------
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_listname = CODELIST.Listname
      FROM WAVE WITH (NOLOCK)
      JOIN CODELIST WITH (NOLOCK) ON WAVE.MBOLGroupMethod = CODELIST.Listname AND CODELIST.ListGroup = 'WAVEMBOLGROUP'
      WHERE WAVE.Wavekey = @c_Wavekey

      IF ISNULL(@c_ListName,'') = ''
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63503
         SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Empty/Invalid MBOL Group Is Not Allowed. (LIST GROUP: WAVEMBOLGROUP) (ispWAVMB01)"
         GOTO RETURN_SP
      END

      --NJOW03 S
      SELECT TOP 1 @c_Condition = CL.UDF05
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.Listname = @c_ListName
      AND CL.Code = 'CONDITION'        
      
      IF ISNULL(@c_Condition,'') <> '' AND LEFT(LTRIM(@c_Condition), 4) <> 'AND '
         SET @c_Condition = 'AND ' + @c_Condition
      
      --NJOW03 E

      DECLARE CUR_CODELKUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT TOP 10 Code, Description, Long
         FROM   CODELKUP WITH (NOLOCK)
         WHERE  ListName = @c_ListName
         AND Code NOT IN('CONDITION') --NJOW03         
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
            SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Grouping Only Allow Refer To Orders Table's Fields. Invalid Table: "+RTRIM(@c_TableColumnName)+" (ispWAVMB01)"
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
            SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Invalid Column Name: " + RTRIM(@c_TableColumnName)+ ". (ispWAVMB01)"
            GOTO RETURN_SP
         END

         IF @c_ColumnType IN ('Float', 'money', 'Int', 'decimal', 'numeric', 'tinyInt', 'real', 'bigInt','text')
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63506
            SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Numeric/Text Column Type Is Not Allowed For MBOL Grouping: " + RTRIM(@c_TableColumnName)+ ". (ispWAVMB01)"
            GOTO RETURN_SP
         END

         IF @c_ColumnType IN ('CHAR', 'NVARCHAR', 'VARCHAR','NCHAR') 
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

         IF @c_ColumnType IN ('datetime')--NJOW02
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
                         + ' JOIN WAVEDETAIL WITH (NOLOCK) ON (ORDERS.OrderKey = WAVEDETAIL.OrderKey) '
                         +'  WHERE WAVEDETAIL.WaveKey = ''' +  RTRIM(@c_WaveKey) +''''
                         + ' AND ISNULL(ORDERS.MBOLKey,'''') = '''' '
                         + ' AND ORDERS.Status NOT IN (''9'',''CANC'') '
                         + RTRIM(ISNULL(@c_Condition,''))  --NJOW03                        
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
                            + ' JOIN WAVEDETAIL WITH (NOLOCK) ON (ORDERS.OrderKey = WAVEDETAIL.OrderKey) '
                            + ' WHERE  ORDERS.StorerKey = @c_StorerKey '
                            + ' AND WAVEDETAIL.WaveKey = @c_WaveKey '
                            + ' AND ORDERS.Status NOT IN (''9'',''CANC'') '
                            + ' AND ISNULL(ORDERS.MBOLKey,'''') <> '''' '
                            + RTRIM(ISNULL(@c_Condition,'')) + ' '  --NJOW03                        
                            + @c_SQLWhere

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

            SELECT TOP 1 @c_Facility = Orders.Facility
            FROM Orders WITH (NOLOCK)
            JOIN WAVEDETAIL WITH (NOLOCK) ON Orders.OrderKey = WAVEDETAIL.Orderkey --NJOW01
            WHERE WAVEDETAIL.Wavekey = @c_WaveKey
            AND Orders.Storerkey = @c_StorerKey
            AND Orders.Status NOT IN ('9','CANC')
            AND ISNULL(Orders.MBOLKey,'') = ''

            -- Create MBOL
            INSERT INTO MBOL (MBOLKey, Facility, PlaceOfdeliveryQualifier, TransMethod, Userdefine09, Userdefine02, Userdefine04) 
            VALUES (@c_MBOLKey, @c_Facility, 'D','O', @c_Userdefine09, @c_Userdefine02, @c_Userdefine04)   --WL01

            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 63507
               SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Insert INTO MBOL Failed. (ispWAVMB01)"
               GOTO RETURN_SP
            END
         END

         SELECT @n_mbolcount = @n_mbolcount + 1

         -- Create mbol detail
         SELECT @c_SQLDYN03 = 'DECLARE cur_mboldet CURSOR FAST_FORWARD READ_ONLY FOR '
                            + ' SELECT ORDERS.OrderKey '
                            + ' FROM ORDERS WITH (NOLOCK) '
                            + ' JOIN WAVEDETAIL WITH (NOLOCK) ON (ORDERS.OrderKey = WAVEDETAIL.OrderKey) '
                            + ' WHERE ORDERS.StorerKey = @c_StorerKey ' +
                            + ' AND WAVEDETAIL.WaveKey = @c_WaveKey '
                            + ' AND ORDERS.Status NOT IN (''9'',''CANC'') '
                            + ' AND ISNULL(ORDERS.MBOLKey,'''') = '''' '
                            + RTRIM(ISNULL(@c_Condition,'')) + ' '  --NJOW03                                                    
                            + @c_SQLWhere
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
                  SELECT @c_errmsg="NSQL"+CONVERT(Char(5),@n_err)+": Insert INTO MBOLDETAIL Failed. (ispWAVMB01)"
                  GOTO RETURN_SP
               END
            END

            FETCH NEXT FROM cur_mboldet INTO @c_OrderKey
         END
         CLOSE cur_mboldet
         DEALLOCATE cur_mboldet
    
         FETCH NEXT FROM cur_MBGroup INTO @c_Storerkey, @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05,
                                          @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10
      END
      CLOSE cur_MBGroup
      DEALLOCATE cur_MBGroup
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @n_mbolcount > 0
         SELECT @c_errmsg = RTRIM(CAST(@n_mbolcount AS Char)) + ' MBOL Generated. Refer to MBOL Userdefine09 for Wave#'
      ELSE
         SELECT @c_errmsg = 'No MBOL Generated'
   END
END

RETURN_SP:

IF @n_continue = 3  -- Error Occured - Process And Return
BEGIN
   IF CURSOR_STATUS('GLOBAL','cur_MBGroup') IN (0,1) 
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
   EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispWAVMB01'
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