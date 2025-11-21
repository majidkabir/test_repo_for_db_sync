SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


create view [dbo].[V_IDS_CCDETAIL_001]
as
	select convert(NVARCHAR(10), rtrim(upper(ccdetail.cckey))) as 'cc_cckey',
		convert(NVARCHAR(10), rtrim(upper(ccdetail.ccdetailkey))) as 'cc_ccdetailkey',
		convert(NVARCHAR(10), rtrim(upper(ccdetail.ccsheetno))) as 'cc_ccsheetno',
		convert(NVARCHAR(10), rtrim(upper(ccdetail.tagno))) as 'cc_tagno',
		convert(NVARCHAR(10), rtrim(upper(ccdetail.storerkey))) as 'cc_storerkey',
		storer.company as 'cc_company',
		convert(NVARCHAR(5), rtrim(upper(loc.facility))) as 'cc_facility',
		facility.descr as 'cc_facility_descr',
		convert(NVARCHAR(20), rtrim(upper(ccdetail.sku))) as 'cc_sku',
		convert(NVARCHAR(20), rtrim(upper(sku.manufacturersku))) as 'cc_manufacturersku',
		convert(NVARCHAR(20), rtrim(upper(sku.retailsku))) as 'cc_retailsku',
		convert(NVARCHAR(20), rtrim(upper(sku.altsku))) as 'cc_altsku',
		(sku.busr1 + sku.busr2) as 'cc_second_lang_descr',
		sku.descr as 'cc_sku_descr',
		convert(NVARCHAR(18), rtrim(upper(sku.susr3))) as 'cc_principal',
		convert(NVARCHAR(10), rtrim(upper(sku.class))) as 'cc_sku_class',
		convert(NVARCHAR(10), rtrim(upper(sku.skugroup))) as 'cc_skugroup',
		code_skugroup.code_desc as 'cc_skugroup_descr',
		convert(NVARCHAR(5), rtrim(upper(sku.abc))) as 'cc_abc',
		code_abc.code_desc as 'cc_sku_abc_descr',
		convert(NVARCHAR(10), rtrim(upper(sku.itemclass))) as 'cc_sku_itemclass',
		code_itemclass.code_desc as 'cc_sku_itemclass_descr',
		convert(NVARCHAR(30), rtrim(upper(sku.busr3))) as 'cc_sku_classification',
		code_skuflag.code_desc as 'cc_sku_classification_descr',
		convert(NVARCHAR(30), rtrim(upper(sku.busr5))) as'cc_product_group',
		convert(NVARCHAR(30), rtrim(upper(sku.busr8))) as 'cc_sku_poison_flag',
		sku.busr9 as 'cc_sku_condition',
		sku.price as 'cc_sku_price',
		sku.cost as 'cc_sku_cost',
		convert(NVARCHAR(10), rtrim(upper(ccdetail.lot))) as 'cc_lot',
		convert(NVARCHAR(10), rtrim(upper(ccdetail.loc))) as 'cc_loc',
		convert(NVARCHAR(18), rtrim(upper(ccdetail.id))) as 'cc_id',
		ccdetail.systemqty as 'cc_systemqty',
		ccdetail.qty as 'cc_qty',
		pack.packuom3 as 'cc_master unit',
		code_uom3.code_desc as 'cc_master_unit_desc',
		pack.qty as 'cc_mu_units',
		pack.packuom2 as 'cc_inner uom',
		code_uom2.code_desc as 'cc_inner_uom_desc',
		pack.innerpack as 'cc_inner_uom_qty',
		pack.packuom1 as 'cc_case_uom',
		code_uom1.code_desc as 'cc_case_uom_desc',
		pack.casecnt as 'cc_case_uom_qty',
		pack.packuom4 as 'cc_pl_uom',
		code_uom4.code_desc as 'cc_pl_uom_desc',
		pack.pallet as 'cc_pl_uom_qty',
		pack.palletti as 'cc_units_per_layer',
		pack.pallethi as 'cc_layers_per_pl',
		sku.lottable01label as 'cc_l1_label',
		code_lottable01.code_desc as 'cc_l1_label_desc',
		ccdetail.lottable01 as 'cc_l1',
		sku.lottable02label as 'cc_l2_label',
		code_lottable02.code_desc as 'cc_l2_label_desc',
		ccdetail.lottable02 as 'cc_l2',
		sku.lottable03label as 'cc_l3_label',
		code_lottable03.code_desc as 'cc_l3_label_desc',	
		ccdetail.lottable03 as 'cc_l3',
		sku.lottable04label as 'cc_l4_label',
		code_lottable04.code_desc as 'cc_l4_label_desc',
		ccdetail.lottable04 as 'cc_l4',
		sku.lottable05label as 'cc_l5_label',
		code_lottable05.code_desc as 'cc_l5_label_desc',
		ccdetail.lottable05 as 'cc_l5',
		ccdetail.finalizeflag as 'cc_finalizeflag',
		ccdetail.qty_cnt2 as 'cc_qty_cnt2',
		ccdetail.lottable01_cnt2 as 'cc_lottable01_cnt2',
		ccdetail.lottable02_cnt2 as 'cc_lottable02_cnt2',
		ccdetail.lottable03_cnt2 as 'cc_lottable03_cnt2',
		ccdetail.lottable04_cnt2 as 'cc_lottable04_cnt2',
		ccdetail.lottable05_cnt2 as 'cc_lottable05_cnt2',
		ccdetail.finalizeflag_cnt2 as 'cc_finalizeflag_cnt2',
		ccdetail.qty_cnt3 as 'cc_qty_cnt3',
		ccdetail.lottable01_cnt3 as 'cc_lottable01_cnt3',
		ccdetail.lottable02_cnt3 as 'cc_lottable02_cnt3',
		ccdetail.lottable03_cnt3 as 'cc_lottable03_cnt3',
		ccdetail.lottable04_cnt3 as 'cc_lottable04_cnt3',
		ccdetail.lottable05_cnt3 as 'cc_lottable05_cnt3',
		ccdetail.finalizeflag_cnt3 as 'cc_finalizeflag_cnt3',
		ccdetail.status as 'cc_status',
		ccdetail.statusmsg as 'cc_statusmsg',
		ccdetail.adddate as 'cc_adddate',
		ccdetail.addwho as 'cc_addwho',
		ccdetail.editdate as 'cc_editdate',
		ccdetail.editwho as 'cc_editwho'
	from ccdetail (nolock) left outer join sku (nolock)
		on ccdetail.storerkey = sku.storerkey
			and ccdetail.sku = sku.sku
	left outer join storer (nolock)
		on ccdetail.storerkey = storer.storerkey
	left outer join pack (nolock)
		on sku.packkey = pack.packkey
	left outer join loc (nolock)
		on ccdetail.loc = loc.loc
	left outer join facility (nolock)
		on loc.facility = facility.facility
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'SKUGROUP') as code_skugroup
		on sku.skugroup = code_skugroup.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'ABC') as code_abc
		on sku.abc = code_abc.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'ITEMCLASS') as code_itemclass
		on sku.itemclass = code_itemclass.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'SKUFLAG') as code_skuflag
		on sku.busr3 = code_skuflag.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'LOTTABLE01') as code_lottable01
		on sku.lottable01label = code_lottable01.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'LOTTABLE02') as code_lottable02
		on sku.lottable02label = code_lottable02.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'LOTTABLE03') as code_lottable03
		on sku.lottable03label = code_lottable03.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'LOTTABLE04') as code_lottable04
		on sku.lottable04label = code_lottable04.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'LOTTABLE05') as code_lottable05
		on sku.lottable05label = code_lottable05.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'QUANTITY') as code_uom1
		on pack.packuom1 = code_uom1.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'QUANTITY') as code_uom2
		on pack.packuom2 = code_uom2.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'QUANTITY') as code_uom3
		on pack.packuom3 = code_uom3.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'QUANTITY') as code_uom4
		on pack.packuom4 = code_uom4.code





GO