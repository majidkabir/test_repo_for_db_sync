SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


CREATE view [dbo].[V_IDS_ORDSUM_001]
as
	select loadplan.casecnt as 'loadplan_casecnt',
				loadplan.palletcnt as 'loadplan_palletcnt',
				loadplan.weight as 'loadplan_weight',
				loadplan.cube as 'loadplan_cube',
				loadplan.custcnt as 'loadplan_custcnt',
				loadplan.trucksize as 'loadplan_trucksize',
				convert(NVARCHAR(15), rtrim(upper(loadplan.carrierkey))) as 'loadplan_carrierkey',
				convert(NVARCHAR(10), rtrim(upper(loadplan.route))) as 'loadplan_route',
				code_load_route.route_desc as 'loadplan_route_descr',
				code_load_route.selfdelivery as 'loadplan_self_delivery',
				code_load_route.handledbywh as 'loadplan_handledbywh',
				loadplan.ordercnt as 'loadplan_ordercnt',
				loadplan.return_weight as 'loadplan_return_weight',
				loadplan.return_cube as 'loadplan_return_cube',
				loadplan.vehicle_type as 'loadplan_vehicle_type',
				convert(NVARCHAR(45), rtrim(upper(loadplan.driver))) as 'loadplan_driver',
				loadplan.delivery_zone as 'loadplan_delivery_zone',
				loadplan.truck_type as 'loadplan_truck_type',
				loadplan.weightlimit as 'loadplan_weightlimit',
				loadplan.volumelimit as 'loadplan_volumelimit',
				loadplan.lpuserdefdate01 as 'loadplan_userdefdate01',
				loadplan.adddate as 'loadplan_adddate',
				loadplan.editdate as 'loadplan_editdate',
				convert(NVARCHAR(5), rtrim(upper(orders.facility))) as 'orders_facility',
				facility.descr as 'facility_descr',
				convert(NVARCHAR(15), rtrim(upper(orders.storerkey))) as 'orders_storerkey',
				storer.company as 'orders_company',
				convert(NVARCHAR(10), rtrim(upper(orders.orderkey))) as 'orders_orderkey',
				convert(NVARCHAR(30), rtrim(upper(orders.externorderkey))) as 'orders_externorderkey',
				orders.orderdate as 'orders_orderdate',
				orders.deliverydate as 'orders_deliverydate',
				orders.priority as 'orders_priority',
				convert(NVARCHAR(15), rtrim(upper(orders.consigneekey))) as 'orders_consigneekey',
				orders.c_contact1 as 'orders_c_contact1',
				orders.c_contact2 as 'orders_c_contact2',
				orders.c_company as 'orders_c_company',
				orders.c_address1 as 'orders_c_address1',
				orders.c_address2 as 'orders_c_address2',
				orders.c_address3 as 'orders_c_address3',
				orders.c_address4 as 'orders_c_address4',
				orders.c_city as 'orders_c_city',
				orders.c_state as 'orders_c_state',
				orders.c_zip as 'orders_c_zip',
				orders.c_country as 'orders_c_country',
				convert(NVARCHAR(10), rtrim(upper(orders.c_isocntrycode))) as 'orders_c_isocntrycode',
				orders.c_phone1 as 'orders_c_phone1',
				orders.c_phone2 as 'orders_c_phone2',
				orders.c_fax1 as 'orders_c_fax1',
				orders.c_fax2 as 'orders_c_fax2',
				orders.c_vat as 'orders_c_vat',
				orders.buyerpo as 'orders_buyerpo',
				convert(NVARCHAR(15), rtrim(upper(orders.billtokey))) as 'orders_billtokey',
				orders.b_contact1 as 'orders_b_contact1',
				orders.b_contact2 as 'orders_b_contact2',
				orders.b_company as 'orders_b_company',
				orders.b_address1 as 'orders_b_address1',
				orders.b_address2 as 'orders_b_address2',
				orders.b_address3 as 'orders_b_address3',
				orders.b_address4 as 'orders_b_address4',
				orders.b_city as 'orders_b_city',
				orders.b_state as 'orders_b_state',
				orders.b_zip as 'orders_b_zip',
				orders.b_country as 'orders_b_country',
				convert(NVARCHAR(10), rtrim(upper(orders.b_isocntrycode))) as 'orders_b_isocntrycode',
				orders.b_phone1 as 'orders_b_phone1',
				orders.b_phone2 as 'orders_b_phone2',
				orders.b_fax1 as 'orders_b_fax1',
				orders.b_fax2 as 'orders_b_fax2',
				orders.b_vat as 'orders_b_vat',
				orders.pmtterm as 'orders_pmtterm',
				code_pmtterm.code_desc as 'orders_pmtterm_desc',
				orders.openqty as 'orders_openqty',
				orders.status as 'orders_status',
				code_ordstatus.code_desc as 'orders_status_desc',
				orders.countryoforigin as 'orders_countryoforigin',
				code_cntry_orig.code_desc as 'orders_country_origin_desc',
				orders.countrydestination as 'orders_countrydestination',
				code_cntry_dest.code_desc as 'orders_country_dest_desc',
				orders.type as 'orders_type',
				code_ordtype.code_desc as 'orders_type_desc',
				convert(NVARCHAR(10), rtrim(upper(orders.route))) as 'orders_route',
				code_orders_route.route_desc as 'orders_route_desc',
				code_orders_route.selfdelivery as 'orders_route_self_delivery',
				code_orders_route.handledbywh as 'orders_route_handledbywh',
				replace(rtrim(convert(NVARCHAR(255), orders.notes)), char(13), '') as 'orders_notes',
				replace(rtrim(convert(NVARCHAR(255), orders.notes2)), char(13), '') as 'orders_notes2',
				orders.adddate as 'orders_adddate',
				orders.addwho as 'orders_addwho',
				orders.editdate as 'orders_editdate',
				orders.editwho as 'orders_editwho',
				orders.sostatus as 'orders_sostatus',
				code_ordsostatus.code_desc as 'orders_sostatus_desc',
				convert(NVARCHAR(10), rtrim(upper(orders.mbolkey))) as 'orders_mbolkey',
				convert(NVARCHAR(10), rtrim(upper(orders.invoiceno))) as 'orders_invoiceno',
				orders.invoiceamount as 'orders_invoiceamount',
				orders.salesman as 'orders_salesman',
				code_salesman.code_desc as 'orders_salesman_desc',
				orders.grossweight as 'orders_grossweight',
				orders.capacity as 'orders_capacity',
				convert(NVARCHAR(10), rtrim(upper(orders.loadkey))) as 'orders_loadkey',
				orders.userdefine05 as 'orders_sellingstorer',
				orders.userdefine08 as 'orders_batch_discrete',
				convert(NVARCHAR(10), rtrim(upper(orders.userdefine09))) as 'orders_wavekey',
				convert(NVARCHAR(10), rtrim(upper(orders.userdefine10))) as 'orders_principal',
				convert(NVARCHAR(5), rtrim(upper(pod.mbollinenumber))) as 'pod_mbollinenumber',
				pod.status as 'pod_status',
				code_podstatus.code_desc as 'pod_status_desc',
				pod.actualdeliverydate as 'pod_delivery_date',
				pod.podreceiveddate as 'pod_pod_received_date',
				pod.redeliverydate as 'pod_redelivery_date',
				pod.fullrejectdate as 'pod_full_reject_date',
				pod.partialrejectdate as 'partial_reject_date',
				convert(NVARCHAR(10), rtrim(upper(pod.rejectreasoncode))) as 'pod_reject_reason_code',
				code_podreject.code_desc as 'pod_reject_reason_code_desc',
				pod.poisonformdate as 'pod_poison_form_date',
				convert(NVARCHAR(10), rtrim(upper(pod.poisonformno))) as 'pod_poison_form_no',
				convert(NVARCHAR(10), rtrim(upper(pod.chequeno))) as 'pod_cheque_no',
				pod.notes as 'pod_comment',
				pod.poddef01 as 'pod_poddef1',
				pod.poddef02 as 'pod_poddef2',
				pod.poddef03 as 'pod_poddef3',
				pod.poddef04 as 'pod_poddef4',
				pod.poddef05 as 'pod_poddef5',
				pod.poddate01 as 'pod_poddate1',
				pod.poddate02 as 'pod_poddate2',
				pod.adddate as 'pod_adddate',
				pod.editdate as 'pod_editdate',
				mbol.status as 'mbol_status',
				code_status.code_desc as 'mbol_status_desc',
				mbol.vesselqualifier as 'mbol_vesselqualifier',
				code_vessels.code_desc as 'mbol_vesselqualifier_desc',
				mbol.vessel as 'mbol_vessel',
				convert(NVARCHAR(30), rtrim(upper(mbol.voyagenumber))) as 'mbol_voyagenumber',
				mbol.departuredate as 'mbol_departuredate',
				mbol.bookingreference as 'mbol_bookingreference',
				mbol.otherreference as 'mbol_otherreference',
				convert(NVARCHAR(10), rtrim(upper(mbol.carrierkey))) as 'mbol_carrierkey',
				mbol.carrieragent as 'mbol_carrieragent',
				mbol.drivername as 'mbol_drivername',
				mbol.loadingdate as 'mbol_loadingdate',
				mbol.customerreceiveddate as 'mbol_customerreceiveddate',
				replace(rtrim(convert(NVARCHAR(255), mbol.remarks)), char(13), '')as 'mbol_remarks',
				mbol.totalinvoicevalue as 'mbol_totalinvoicevalue',
				mbol.invoiceamount as 'mbol_invoiceamout',
				mbol.cod_status as 'mbol_cod_status',
				mbol.depotstatus as 'mbol_depotstatus',
				mbol.adddate as 'mbol_adddate',
				mbol.editdate as 'mbol_editdate'
	from orders (nolock) 
	join storer (nolock)
		on orders.storerkey = storer.storerkey
   left outer join orderdetail (nolock)
		on orders.orderkey = orderdetail.orderkey
	left outer join facility (nolock)
		on orders.facility = facility.facility
	left outer join (select distinct case
										when od.loadkey = '' or od.loadkey is null then o.loadkey
										else od.loadkey
								  	end 'loadkey'
						  from orders o (nolock) left outer join orderdetail od (nolock)
						  on o.orderkey = od.orderkey) as lk
		on orders.loadkey = lk.loadkey
	left outer join loadplan (nolock)
		on orders.loadkey = loadplan.loadkey
	left outer join mbol (nolock)
		on orderdetail.mbolkey = mbol.mbolkey
	left outer join pod (nolock)
		on orders.orderkey = pod.orderkey
	left outer join (select route, descr as 'route_desc', selfdelivery, handledbywh
						  from routemaster (nolock)) as code_load_route
		on loadplan.route = code_load_route.route
	left outer join (select route, descr as 'route_desc', selfdelivery, handledbywh
						  from routemaster (nolock)) as code_orders_route
		on orders.route = code_orders_route.route
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'PMTTERM') as code_pmtterm
		on orders.pmtterm = code_pmtterm.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						 where listname = 'ORDRSTATUS') as code_ordstatus
		on orders.status = code_ordstatus.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'ISOCOUNTRY') as code_cntry_orig
		on orders.countryoforigin = code_cntry_orig.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'ISOCOUNTRY') as code_cntry_dest
		on orders.countrydestination = code_cntry_dest.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'ORDERTYPE') as code_ordtype
		on orders.type = code_ordtype.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'SOSTATUS') as code_ordsostatus
		on orders.sostatus = code_ordsostatus.code	
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'SALESCODE') as code_salesman
		on orders.salesman = code_salesman.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'QUANTITY') as code_uom
		on orderdetail.uom = code_uom.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'ORDRSTATUS') as code_detail_status
		on orderdetail.status = code_detail_status.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'PODSTATUS') as code_podstatus
		on pod.status = code_podstatus.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'PODREJECT') as code_podreject
		on pod.rejectreasoncode = code_podreject.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'STATUS') as code_status
		on mbol.status = code_status.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'VESSELS') as code_vessels
		on mbol.vesselqualifier = code_vessels.code





GO