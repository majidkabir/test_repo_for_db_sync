SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispMBCHK01                                         */
/* Creation Date: 09-May-2011                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: SOS#214494 - TH Extended Mbol Validation                    */
/*                                                                      */
/* Called By: isp_ValidateMBOL                                          */
/*            (Storerconfig MBOLExtendedValidation)                     */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 27-Sep-2013  Audrey   1.1  SOS#290702 -  Add message into            */
/*                                          MBOLErrerReport    (ang01)  */
/* 11-Oct-2013  NJOW01   1.2  291876 - Shipment# validation. All Ship#  */
/*                            must ship in same MBOL                    */
/************************************************************************/
CREATE PROCEDURE [dbo].[ispMBCHK01]
   @c_MBOLKey    NVARCHAR(10),
   @cStorerkey  NVARCHAR(15),
   @nSuccess     INT         OUTPUT,
   @n_Err        INT          OUTPUT,
   @c_ErrMsg     NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_ScanCount INT,
           @n_PackCount INT,
           @n_Continue  INT,
           @c_Shipmentno NVARCHAR(30) --NJOW01

   SELECT @n_Err=0, @nSuccess=1, @c_ErrMsg='', @n_Continue = 1

   SELECT @n_ScanCount = COUNT(DISTINCT PD.Caseid)
   FROM Container C (NOLOCK)
   JOIN ContainerDetail CD (NOLOCK) ON C.Containerkey = CD.Containerkey
   JOIN Pallet P (NOLOCK) ON (CD.Palletkey = P.Palletkey)
   JOIN PalletDetail PD (NOLOCK) ON (P.Palletkey = PD.Palletkey)
   WHERE C.Mbolkey = @c_Mbolkey

   SELECT @n_PackCount = COUNT(DISTINCT PD.Labelno)
   FROM MBOLDETAIL MD (NOLOCK)
   JOIN PACKHEADER PH (NOLOCK) ON MD.Orderkey = PH.Orderkey
   JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno
   WHERE MD.Mbolkey = @c_Mbolkey

   IF @n_ScanCount <> @n_PackCount
   BEGIN
       SELECT @n_continue = 3
       SELECT @n_Err = 31210
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) +
              ': Total Carton PACKED('+ CAST(@n_packcount as varchar)+') mismatch with Total Carton Loaded('+ CAST(@n_scancount as varchar) +') for MBOL# '+RTRIM(@c_MBOLKey)+' (ispMBCHK01)'
/*ang01 start */
       INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                              '-----------------------------------------------------')
       INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERRORMSG',
                                                                              'Total Carton PACKED('+ CAST(@n_packcount as varchar)+') mismatch with Total Carton Loaded('+ CAST(@n_scancount as varchar) +') for MBOL# '+RTRIM(@c_MBOLKey)+' (ispMBCHK01)')
       INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                              '-----------------------------------------------------')
/*ang01 end */  
       GOTO QUIT_SP
   END
   
   --NJOW01 Start   
   SELECT DISTINCT ORDERS.Salesman AS ShipmentNo
   INTO #TMP_SHIPMENT
   FROM MBOLDETAIL (NOLOCK)  
   JOIN ORDERS (NOLOCK) ON MBOLDETAIL.Orderkey = ORDERS.Orderkey
   JOIN CODELKUP (NOLOCK) ON ORDERS.Storerkey = CODELKUP.Storerkey AND CODELKUP.Listname = 'ISPMBCHK01' AND CODELKUP.Code = 'CHKFULLSHIPMENT'
   WHERE MBOLDETAIL.Mbolkey = @c_MBOLKey
   AND ISNULL(ORDERS.Salesman,'') <> ''
   
   SELECT CONVERT(NCHAR(10), ISNULL(ORDERS.Mbolkey,'')) + ' '     
              + CONVERT(NCHAR(10), ORDERS.Orderkey) + ' '     
              + CONVERT(NCHAR(30), ISNULL(ORDERS.Salesman,'')) AS LineText
   INTO #TMP_ErrorLogDetail
   FROM ORDERS (NOLOCK)
   JOIN #TMP_SHIPMENT S ON ORDERS.Salesman = S.ShipmentNo
   JOIN CODELKUP (NOLOCK) ON ORDERS.Storerkey = CODELKUP.Storerkey AND CODELKUP.Listname = 'ISPMBCHK01' AND CODELKUP.Code = 'CHKFULLSHIPMENT'
   WHERE ORDERS.Mbolkey <> @c_Mbolkey
   GROUP BY ORDERS.Mbolkey, ORDERS.Orderkey, ORDERS.Salesman
   ORDER BY ORDERS.Mbolkey, ORDERS.Orderkey, ORDERS.Salesman
   
   IF @@ROWCOUNT > 0 
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_Err = 31211
      SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) +
             'Shipment# Not Fully Ship In Current MBOL#' + @c_mbolkey+' (ispMBCHK01)'

      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',   
                                                                             '-----------------------------------------------------')               
      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERRORMSG',    
                                                                             'Shipment# Not Fully Ship In Current MBOL#' + @c_mbolkey)      
      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',    
                                                                             '-----------------------------------------------------')      
      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',      
                                   CONVERT(NCHAR(10), 'MBOLKey') + ' '     
                                 + CONVERT(NCHAR(10), 'OrderKey') + ' '     
                                 + CONVERT(NCHAR(30), 'Shipment No')
                                 )        
      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',      
                                   REPLICATE('-', 10) + ' '     
                                 + CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '     
                                 + CONVERT(NCHAR(30), REPLICATE('-', 30)) 
                                 )           
      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)    
      SELECT @c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR', LineText    
      FROM #TMP_ErrorLogDetail       	
      
      GOTO QUIT_SP
   END
   --NJOW01 End

   QUIT_SP:
   IF @n_Continue = 3
   BEGIN
      SET @nSuccess = 0
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispMBCHK01'
   END
   ELSE
   BEGIN
      SET @nSuccess = 1
   END
END

GO