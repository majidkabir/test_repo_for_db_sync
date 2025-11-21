SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************/
-- PH_LogiReport - ColPal_ScanToTruck [SP] https://jiralfl.atlassian.net/browse/WMS-21703
/* Updates:                                                                           */
/* Date         Author         Ver.  Purposes                                          */
/* 14-Feb-2023  ziwei          1.0   Created                                           */
/***************************************************************************************/

   CREATE    PROCEDURE [BI].[nsp_STD_ScanToTruck]
			@PARAM_GENERIC_STORERKEY NVARCHAR(30)='PH01'
		  ,@PARAM_GENERIC_FACILITY NVARCHAR(30)='PH50'
		  ,@PARAM_GENERIC_ADDDATEFROM DATETIME='2022-12-20'
		  ,@PARAM_Generic_AddDateTo DATETIME='2022-12-31'
   
   AS
   BEGIN
      SET NOCOUNT ON;  -- keeps the output generated to a minimum 
      SET ANSI_NULLS OFF;
      SET QUOTED_IDENTIFIER OFF;
      SET CONCAT_NULL_YIELDS_NULL OFF;

   DECLARE @Debug	BIT = 0
		 , @LogId   INT
       , @LinkSrv   NVARCHAR(128)
       , @Schema    NVARCHAR(128) = ISNULL(OBJECT_SCHEMA_NAME(@@PROCID),'')
       , @Proc      NVARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'') --NAME OF SP
       , @cParamOut NVARCHAR(4000)= ''
       , @cParamIn  NVARCHAR(4000)= ''

   EXEC BI.dspExecInit @ClientId = @PARAM_GENERIC_STORERKEY
   , @Proc = @Proc
   , @ParamIn = @cParamIn
   , @LogId = @LogId OUTPUT
   , @Debug = @Debug OUTPUT
   , @Schema = @Schema;


   DECLARE @Stmt NVARCHAR(MAX) = '' -- for storing dynamic SQL Statement

   SET @stmt = CONCAT(@stmt , '
   SELECT distinct O.facility,
   O.C_Company as ''Ship To'',
   O.Loadkey,
   O.MBOLkey as ''ShipRef'',
   T.Adddate as ''Booking Date'',
   T.Bookingno,
   B.Loc as ''Bay'',
   P.Dropid,
   sum (P.Qty) as ''Drop ID quantity'',
   case
   when R.Status IS NULL  then ''0''
   else ''9''
   end as ''Status'',
   R.Addwho as ''RDT User'',
   R.editdate as ''Scanned Time''
   
   FROM BI.V_orders O WITH (nolock)
   
   LEFT JOIN BI.V_pickdetail P WITH (nolock) on O.orderkey = P.orderkey
   LEFT JOIN BI.V_rdtscantotruck R (nolock) on P.dropid = R.URNNo
   LEFT JOIN BI.V_tms_shipment T (nolock) on O.loadkey = T.ShipmentGID
   LEFT JOIN BI.V_Booking_out B WITH(nolock) on T.bookingno=B.bookingno
      
   WHERE O.StorerKey = ''',@PARAM_Generic_Storerkey,'''
   AND O.Facility= ''',@PARAM_Generic_Facility,'''
   AND O.AddDate >= Convert(date, ''',@PARAM_Generic_AddDateFrom,''') 
   and O.AddDate < DateAdd(day, 1, Convert(date, ''',@PARAM_Generic_AddDateTo,'''))
  
   GROUP BY O.facility, O.C_Company,O.Loadkey,O.MBOLkey,T.Adddate,
   T.Bookingno,P.Dropid,R.Addwho,R.editdate,B.Loc,R.Status

')

 

   
   EXEC BI.dspExecStmt @Stmt = @stmt
   , @LinkSrv = @LinkSrv
   , @LogId = @LogId
   , @Debug = @Debug;
  
END

GO