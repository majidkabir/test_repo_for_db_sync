SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***********************************************************************
	TITLE: TASK MANAGER REPORT (PHWMS) https://jiralfl.atlassian.net/browse/WMS-21993

DATE				VER		CREATEDBY   PURPOSE
14-MAR-2023			1.0		JAM			MIGRATE FROM HYPERION (PHWMS)
31-MAR-2023       1.1      Crisnah  Change param character length
************************************************************************/

CREATE     PROC [BI].[nsp_STD_PHWMS_TaskManager] --NAME OF SP
			@PARAM_GENERIC_STORERKEY NVARCHAR(30)		
			, @PARAM_GENERIC_FACILITY NVARCHAR(10)		
			, @PARAM_GENERIC_ADDDATEFROM DATETIME		
			, @PARAM_GENERIC_ADDDATETO DATETIME			
			, @PARAM_GENERIC_TASKTYPE NVARCHAR (500)		-- EXTEND CHARACTERS DUE TO MULTIPLE VALUE TYPE
			, @PARAM_TMREPORT_STATUS NVARCHAR (100) -- EXTEND CHARACTERS DUE TO MULTIPLE VALUE TYPE

AS
BEGIN
 SET NOCOUNT ON;  -- keeps the output generated to a minimum 
   SET ANSI_NULLS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;

	IF ISNULL(@PARAM_GENERIC_StorerKey, '') = ''
		SET @PARAM_GENERIC_StorerKey = ''

	SET @PARAM_GENERIC_TASKTYPE = REPLACE(REPLACE (TRANSLATE (@PARAM_GENERIC_TASKTYPE,'[ ]',''' '''),'''',''),', ',''',''')
	SET @PARAM_TMREPORT_STATUS = REPLACE(REPLACE (TRANSLATE (@PARAM_TMREPORT_STATUS,'[ ]',''' '''),'''',''),', ',''',''')

   DECLARE @Debug	BIT = 0
		 , @LogId   INT
       , @Schema    NVARCHAR(128) = ISNULL(OBJECT_SCHEMA_NAME(@@PROCID),'')
       , @Proc      NVARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'') --NAME OF SP
       , @cParamOut NVARCHAR(4000)= ''
       , @cParamIn  NVARCHAR(4000)= CONCAT('{ "PARAM_GENERIC_StorerKey":"'    ,@PARAM_GENERIC_StorerKey,'"'
                                    , ', "PARAM_GENERIC_FACILITY":"'    ,@PARAM_GENERIC_FACILITY,'"'
									         , ', "PARAM_GENERIC_TASKTYPE":"'    ,@PARAM_GENERIC_TASKTYPE,'"'
									         , ', "PARAM_TMREPORT_STATUS":"'    ,@PARAM_TMREPORT_STATUS,'"'
                                    , ', "PARAM_GENERIC_ADDDATEFROM":"',CONVERT(NVARCHAR(19),@PARAM_GENERIC_ADDDATEFROM,121),'"'
                                    , ', "PARAM_GENERIC_ADDDATETO":"',CONVERT(NVARCHAR(19),@PARAM_GENERIC_ADDDATETO,121),'"'
                                    , ' }')

   EXEC BI.dspExecInit @ClientId = @PARAM_GENERIC_StorerKey
   , @Proc = @Proc
   , @ParamIn = @cParamIn
   , @LogId = @LogId OUTPUT
   , @Debug = @Debug OUTPUT
   , @Schema = @Schema;

DECLARE @Stmt NVARCHAR(MAX) = '' -- for dynamic SQL only
	
/****** START YOUR SELECT STATEMENT HERE USE @Stmt FOR DYNAMIC SQL ******/

SET @stmt = @stmt + '

SELECT

T.Taskdetailkey		AS ''01Taskdetailkey'',
T.Groupkey			AS ''02Groupkey'',
T.Dropid			AS ''03Dropid'',
T.Storerkey			AS ''04Storerkey'',
T.Tasktype			AS ''05Tasktype'',
T.Pickmethod		AS ''06Pickmethod'',
T.Areakey			AS ''07Areakey'',
T.Sku				AS ''08Sku'',
S.Descr				AS ''09SKUDescr'',
T.Lot				AS ''10Lot'',
T.Uom				AS ''11Uom'',
T.Fromloc			AS ''12Fromloc'',
T.Toloc				AS ''13Toloc'',
T.Fromid			AS ''14Fromid'',
T.Toid				AS ''15Toid'',
T.Caseid			AS ''16Caseid'',
T.Status			AS ''17Status'',
T.Priority			AS ''18Priority'',
T.Sourcepriority	AS ''19Sourcepriority'',
T.Holdkey			AS ''20Holdkey'',
T.Userkeyoverride	AS ''21Userkeyoverride'',
T.Sourcekey			AS ''22Sourcekey'',
T.Listkey			AS ''23Listkey'',
T.Reasonkey			AS ''24Reasonkey'',
T.Starttime			AS ''25Starttime'',
T.Endtime			AS ''26Endtime'',
T.Message01			AS ''27BookingTime'',
T.Adddate			AS ''28Adddate'',
T.Addwho			AS ''29Addwho'',
T.Editdate			AS ''30Editdate'',
T.Editwho			AS ''31Editwho'',
T.Reftaskkey		AS ''32Reftaskkey'',
T.Userkey			AS ''33Userkey'',
R.Fullname			AS ''34Fullname'',
T.LogicalFromLoc	AS ''35LOGICALFROMLOC'',
T.LogicalToLoc		AS ''36LOGICALTOLOC'',
T.Loadkey			AS ''37Loadkey'',
ST.Company			AS ''38Hauler'',
MAX(LD.Customername) AS ''39CustomerName'',
T.Message01			AS ''40Message01'',
T.Message02			AS ''41Message02'',
T.Message03			AS ''42Message03'',
T.Transitcount		AS ''43Transitcount'',
T.Transitloc		AS ''44Transitloc'',
T.Finalloc			AS ''45Finalloc'',
T.Finalid			AS ''46Finalid'',
RO.Descr			AS ''47RouteDescr'',
T.Systemqty			AS ''48ReleasedQty'',
T.Qty				AS ''49ConfirmedQty'',
case when P.Casecnt>0 then T.Systemqty/P.Casecnt else 0 end   AS ''50ReleasedQty_CS'',
case when P.Casecnt>0 then T.Qty/P.Casecnt else 0 end		  AS ''51ConfirmedQty_CS'',
case when P.Pallet>0 then T.Systemqty /P.Pallet else 0 end    AS ''52ReleasedQty_PL'',
case when P.Pallet>0 then T.Qty/P.Pallet else 0 end           AS ''53ConfirmedQty_PL'',
S.Stdcube * T.Qty											  AS ''54TotalCBM'',
LP.Externloadkey											  AS ''55Externloadkey''
,L.Locationtype [FromLocType]
,L2.Locationtype [ToLocType]
,L.Locaisle [FromLocaisle]
,L2.Locaisle [ToLocaisle]
,T.Pickdetailkey, T.Orderkey, T.OrderlineNumber, T.Listkey, T.Wavekey
'

SET @stmt = @stmt + '

FROM 
BI.V_TASKDETAIL T
JOIN BI.V_LOC L ON (T.FROMLOC = L.LOC)
JOIN BI.V_LOC L2 ON (T.TOLOC = L2.LOC)
LEFT OUTER JOIN BI.V_RDTUser R WITH (NOLOCK) ON (R.USERNAME = T.USERKEY)
LEFT OUTER JOIN BI.V_SKU S ON  (S.SKU = T.SKU AND S.STORERKEY = T.STORERKEY)
LEFT OUTER JOIN BI.V_PACK P ON (S.PACKKEY = P.PACKKEY)
LEFT OUTER JOIN BI.V_LOADPLAN LP ON (T.LOADKEY = LP.LOADKEY)
LEFT OUTER JOIN BI.V_ROUTEMASTER RO ON (LP.ROUTE = RO.ROUTE)
LEFT OUTER JOIN BI.V_STORER ST ON (LP.CARRIERKEY = ST.STORERKEY)
LEFT OUTER JOIN BI.V_LOADPLANDETAIL LD ON (T.LOADKEY = LD.LOADKEY)


WHERE 

((T.ADDDATE BETWEEN ''' +CONVERT(NVARCHAR(19),@PARAM_GENERIC_ADDDATEFROM,121)+''' 
AND '''+CONVERT(NVARCHAR(19),@PARAM_GENERIC_ADDDATETO	,121)+''') 
AND T.Storerkey = '''+@Param_Generic_Storerkey+'''
AND T.TaskType IN ('''+@PARAM_GENERIC_TASKTYPE+''')
AND T.STATUS IN ('''+@PARAM_TMREPORT_STATUS+''')
AND L.Facility= '''+@PARAM_GENERIC_FACILITY+''')
'
SET @stmt = CONCAT(@stmt , '

GROUP BY 
T.Taskdetailkey,
T.Tasktype,
T.Storerkey,
T.Sku,
S.Descr,
T.Lot,
T.Uom,
T.Fromloc,
T.Fromid,
T.Toloc,
T.Toid,
T.Caseid,
T.Pickmethod,
T.Status,
T.Priority,
T.Sourcepriority,
T.Holdkey,
T.Userkeyoverride,
T.Starttime,
T.Endtime,
T.Sourcetype,
T.Sourcekey,
T.Listkey,
T.Reasonkey,
T.Message01,
T.Message01,
T.Message02,
T.Message03,
T.Adddate,
T.Addwho,
T.Editdate,
T.Editwho,
T.Trafficcop,
T.Archivecop,
T.Reftaskkey,
T.Loadkey,
ST.Company,
T.Dropid,
T.Transitcount,
T.Transitloc,
T.Finalloc,
T.Finalid,
T.Userkey,
R.Fullname,
T.LogicalFromLoc,
T.LogicalToLoc,
T.Groupkey,
T.Areakey,
RO.Descr,
T.Systemqty,
T.Qty,
case when P.Casecnt>0 then T.Systemqty/P.Casecnt else 0 end  ,
case when P.Casecnt>0 then T.Qty/P.Casecnt else 0 end,
case when P.Pallet>0 then T.Systemqty /P.Pallet else 0 end  ,
case when P.Pallet>0 then T.Qty/P.Pallet else 0 end  ,
S.Stdcube * T.Qty,
LP.Externloadkey
,L.Locationtype
,L2.Locationtype
,L.Locaisle
,L2.Locaisle
,T.Pickdetailkey, T.Orderkey, T.OrderlineNumber, T.Listkey, T.Wavekey

ORDER BY  27,  38,  49

');

-- USE VIEW TABLES WITH BI SCHEMA : BI.V_DM_ORDERS for PH_DATAMART, BI.V_ORDERS for PHWMS

/*************************** FOOTER *******************************/
   EXEC BI.dspExecStmt @Stmt = @stmt
   , @LogId = @LogId
   , @Debug = @Debug;

END

GO